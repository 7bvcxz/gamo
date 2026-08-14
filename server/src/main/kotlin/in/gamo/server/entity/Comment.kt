package `in`.gamo.server.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.Instant

/**
 * There are exactly two voices here, and that is a rule rather than a default.
 *
 * An open author field would drift into "me", "merti", "user", "claude",
 * "Claude Code" and then need normalising; a thread whose speakers cannot be
 * told apart is a thread nobody can re-read later. Two values, checked by the
 * database.
 */
enum class CommentAuthor { HUMAN, CLAUDE }

@Entity
@Table(name = "decision_comments")
class Comment(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "decision_id", nullable = false)
    var decision: Decision? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    var author: CommentAuthor = CommentAuthor.HUMAN,

    @Column(columnDefinition = "text", nullable = false)
    var body: String = "",

    var createdAt: Instant = Instant.now(),
)
