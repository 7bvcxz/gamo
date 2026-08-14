package `in`.gamo.server.service

import `in`.gamo.server.entity.Comment
import `in`.gamo.server.entity.CommentAuthor
import `in`.gamo.server.entity.Decision
import `in`.gamo.server.entity.DecisionPriority
import `in`.gamo.server.entity.DecisionStatus
import `in`.gamo.server.repository.CommentRepository
import `in`.gamo.server.repository.DecisionRepository
import jakarta.persistence.criteria.Predicate
import org.springframework.data.jpa.domain.Specification
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

data class CommentDto(
    val id: Long,
    val author: String,
    val body: String,
    val createdAt: String,
)

data class DecisionDto(
    val id: Long,
    val title: String,
    val body: String,
    val status: String,
    val priority: String,
    val category: String,
    val outcome: String,
    val createdAt: String,
    val updatedAt: String,
    val comments: List<CommentDto>,
)

/** Everything is optional so a PATCH can carry only what changed. */
data class DecisionInput(
    val title: String? = null,
    val body: String? = null,
    val status: String? = null,
    val priority: String? = null,
    val category: String? = null,
    val outcome: String? = null,
)

data class CommentInput(
    val author: String? = null,
    val body: String? = null,
)

class NotFound(message: String) : RuntimeException(message)
class BadInput(message: String) : RuntimeException(message)

@Service
class DecisionService(
    private val decisions: DecisionRepository,
    private val comments: CommentRepository,
) {
    @Transactional(readOnly = true)
    fun list(status: String?, priority: String?, category: String?, query: String?): List<DecisionDto> {
        val spec = Specification<Decision> { root, _, cb ->
            val parts = mutableListOf<Predicate>()
            status?.takeIf { it.isNotBlank() }?.let {
                parts += cb.equal(root.get<DecisionStatus>("status"), parseStatus(it))
            }
            priority?.takeIf { it.isNotBlank() }?.let {
                parts += cb.equal(root.get<DecisionPriority>("priority"), parsePriority(it))
            }
            category?.takeIf { it.isNotBlank() }?.let {
                parts += cb.equal(cb.lower(root.get("category")), it.lowercase())
            }
            query?.takeIf { it.isNotBlank() }?.let {
                val like = "%${it.lowercase()}%"
                parts += cb.or(
                    cb.like(cb.lower(root.get("title")), like),
                    cb.like(cb.lower(root.get("body")), like),
                    cb.like(cb.lower(root.get("outcome")), like),
                )
            }
            if (parts.isEmpty()) null else cb.and(*parts.toTypedArray())
        }
        // Priority first, then most recently touched. An open P0 that was
        // discussed this morning is the thing the page exists to put in front of
        // someone; sorting by id would bury it under whatever was entered last.
        return decisions.findAll(spec)
            .sortedWith(compareBy({ it.priority.ordinal }, { -it.updatedAt.toEpochMilli() }))
            .map { it.toDto() }
    }

    @Transactional(readOnly = true)
    fun get(id: Long): DecisionDto = find(id).toDto()

    @Transactional
    fun create(input: DecisionInput): DecisionDto {
        val title = input.title?.trim().orEmpty()
        if (title.isEmpty()) throw BadInput("title is required")
        val decision = Decision(
            title = title,
            body = input.body.orEmpty(),
            status = input.status?.let { parseStatus(it) } ?: DecisionStatus.OPEN,
            priority = input.priority?.let { parsePriority(it) } ?: DecisionPriority.P2,
            category = input.category?.trim()?.takeIf { it.isNotEmpty() } ?: "general",
            outcome = input.outcome.orEmpty(),
        )
        return decisions.save(decision).toDto()
    }

    @Transactional
    fun update(id: Long, input: DecisionInput): DecisionDto {
        val decision = find(id)
        input.title?.let {
            val trimmed = it.trim()
            if (trimmed.isEmpty()) throw BadInput("title cannot be empty")
            decision.title = trimmed
        }
        input.body?.let { decision.body = it }
        input.status?.let { decision.status = parseStatus(it) }
        input.priority?.let { decision.priority = parsePriority(it) }
        input.category?.let { decision.category = it.trim().takeIf(String::isNotEmpty) ?: "general" }
        input.outcome?.let { decision.outcome = it }
        // Set here as well as in @PreUpdate: a PATCH that only touches the
        // comment list would not trigger a dirty check on the decision row, and
        // the list sorts by this.
        decision.updatedAt = Instant.now()
        return decisions.save(decision).toDto()
    }

    @Transactional
    fun delete(id: Long) {
        decisions.delete(find(id))
    }

    @Transactional
    fun addComment(id: Long, input: CommentInput): DecisionDto {
        val body = input.body?.trim().orEmpty()
        if (body.isEmpty()) throw BadInput("body is required")
        val decision = find(id)
        val comment = Comment(
            decision = decision,
            author = parseAuthor(input.author),
            body = body,
        )
        decision.comments.add(comment)
        decision.updatedAt = Instant.now()
        return decisions.save(decision).toDto()
    }

    @Transactional
    fun deleteComment(id: Long, commentId: Long): DecisionDto {
        val decision = find(id)
        val comment = decision.comments.firstOrNull { it.id == commentId }
            ?: throw NotFound("comment $commentId not found on decision $id")
        decision.comments.remove(comment)
        comments.delete(comment)
        decision.updatedAt = Instant.now()
        return decisions.save(decision).toDto()
    }

    private fun find(id: Long): Decision =
        decisions.findById(id).orElseThrow { NotFound("decision $id not found") }

    // Parsed rather than trusted. These arrive from a browser and from a shell,
    // and an unrecognised value has to be a 400 rather than a silent default --
    // a comment filed as HUMAN because "claude" was not spelled the way this
    // enum expects is worse than a rejected request.
    private fun parseStatus(value: String): DecisionStatus =
        runCatching { DecisionStatus.valueOf(value.trim().uppercase()) }
            .getOrElse { throw BadInput("status must be one of ${DecisionStatus.entries.joinToString()}") }

    private fun parsePriority(value: String): DecisionPriority =
        runCatching { DecisionPriority.valueOf(value.trim().uppercase()) }
            .getOrElse { throw BadInput("priority must be one of ${DecisionPriority.entries.joinToString()}") }

    private fun parseAuthor(value: String?): CommentAuthor {
        val raw = value?.trim().orEmpty()
        if (raw.isEmpty()) throw BadInput("author is required: HUMAN or CLAUDE")
        return runCatching { CommentAuthor.valueOf(raw.uppercase()) }
            .getOrElse { throw BadInput("author must be HUMAN or CLAUDE") }
    }
}

private fun Decision.toDto() = DecisionDto(
    id = id ?: 0,
    title = title,
    body = body,
    status = status.name,
    priority = priority.name,
    category = category,
    outcome = outcome,
    createdAt = createdAt.toString(),
    updatedAt = updatedAt.toString(),
    comments = comments
        .sortedWith(compareBy({ it.createdAt }, { it.id ?: 0 }))
        .map {
            CommentDto(
                id = it.id ?: 0,
                author = it.author.name,
                body = it.body,
                createdAt = it.createdAt.toString(),
            )
        },
)
