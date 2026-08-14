package `in`.gamo.server.controller

import `in`.gamo.server.service.BadInput
import `in`.gamo.server.service.CommentInput
import `in`.gamo.server.service.DecisionDto
import `in`.gamo.server.service.DecisionInput
import `in`.gamo.server.service.DecisionService
import `in`.gamo.server.service.NotFound
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

/**
 * The decisions API.
 *
 * Shaped after the one the admin page in modulo talks to, because that is the
 * page this one is modelled on and two tools with the same job should not need
 * two mental models. The paths are the resource and nothing else: no verbs, no
 * action endpoints.
 */
@RestController
@RequestMapping("/api/gamo/v1/decisions")
class DecisionController(private val service: DecisionService) {

    @GetMapping
    fun list(
        @RequestParam(required = false) status: String?,
        @RequestParam(required = false) priority: String?,
        @RequestParam(required = false) category: String?,
        @RequestParam(required = false) q: String?,
    ): Map<String, Any> = mapOf("items" to service.list(status, priority, category, q))

    @GetMapping("/{id}")
    fun get(@PathVariable id: Long): DecisionDto = service.get(id)

    @PostMapping
    fun create(@RequestBody input: DecisionInput): DecisionDto = service.create(input)

    @PatchMapping("/{id}")
    fun update(@PathVariable id: Long, @RequestBody input: DecisionInput): DecisionDto =
        service.update(id, input)

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long): Map<String, Any> {
        service.delete(id)
        return mapOf("deleted" to id)
    }

    /** Returns the whole decision, so a page that just posted a comment does not
     *  have to fetch again to redraw the thread. */
    @PostMapping("/{id}/comments")
    fun addComment(@PathVariable id: Long, @RequestBody input: CommentInput): DecisionDto =
        service.addComment(id, input)

    @DeleteMapping("/{id}/comments/{commentId}")
    fun deleteComment(@PathVariable id: Long, @PathVariable commentId: Long): DecisionDto =
        service.deleteComment(id, commentId)

    @ExceptionHandler(NotFound::class)
    fun notFound(error: NotFound): ResponseEntity<Map<String, String>> =
        ResponseEntity.status(404).body(mapOf("error" to (error.message ?: "not found")))

    @ExceptionHandler(BadInput::class)
    fun badInput(error: BadInput): ResponseEntity<Map<String, String>> =
        ResponseEntity.badRequest().body(mapOf("error" to (error.message ?: "bad request")))
}
