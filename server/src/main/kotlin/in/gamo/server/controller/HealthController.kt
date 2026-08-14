package `in`.gamo.server.controller

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.Instant

/** What the page asks before deciding whether it can offer editing. */
@RestController
@RequestMapping("/api")
class HealthController {
    @GetMapping("/ping")
    fun ping(): Map<String, Any> = mapOf(
        "status" to "ok",
        "service" to "gamo-server",
        "timestamp" to Instant.now().toString(),
    )
}
