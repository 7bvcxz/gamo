package `in`.gamo.server.entity

import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.OneToMany
import jakarta.persistence.OrderBy
import jakarta.persistence.PreUpdate
import jakarta.persistence.Table
import java.time.Instant

/**
 * Where a decision stands.
 *
 * OPEN is the honest default and the one that matters: this tool exists because
 * two questions about the game -- how long a day is, and what happens to the
 * gacha -- were written into a design document as `[질문]` and would otherwise
 * have sat there being read and not answered.
 */
enum class DecisionStatus { OPEN, DECIDED, DEFERRED, DROPPED }

/** P0 first, matching the design documents rather than inventing a second scale. */
enum class DecisionPriority { P0, P1, P2, P3, P4 }

@Entity
@Table(name = "decisions")
class Decision(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(nullable = false, length = 300)
    var title: String = "",

    /** What the decision is about. Markdown; the page renders it. */
    @Column(columnDefinition = "text")
    var body: String = "",

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    var status: DecisionStatus = DecisionStatus.OPEN,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 4)
    var priority: DecisionPriority = DecisionPriority.P2,

    /** Free text rather than an enum: the categories this game needs are not
     *  known yet, and an enum here would mean a deploy every time one is. */
    @Column(nullable = false, length = 60)
    var category: String = "general",

    /** What was actually decided, once it was. Separate from `body` so the
     *  question survives the answer -- a decision whose reasoning has been
     *  overwritten by its conclusion cannot be revisited. */
    @Column(columnDefinition = "text")
    var outcome: String = "",

    var createdAt: Instant = Instant.now(),
    var updatedAt: Instant = Instant.now(),

    /**
     * Loaded with the decision and ordered oldest first, because a decision's
     * comments are the argument that produced it and an argument out of order
     * is not one.
     */
    @OneToMany(
        mappedBy = "decision",
        cascade = [CascadeType.ALL],
        orphanRemoval = true,
        fetch = FetchType.EAGER,
    )
    @OrderBy("createdAt ASC, id ASC")
    var comments: MutableList<Comment> = mutableListOf(),
) {
    @PreUpdate
    fun touch() {
        updatedAt = Instant.now()
    }
}
