package `in`.gamo.server.repository

import `in`.gamo.server.entity.Comment
import `in`.gamo.server.entity.Decision
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.JpaSpecificationExecutor

/**
 * Specifications rather than a derived query per filter combination. The page
 * filters by status, priority, category and free text in any combination, which
 * is sixteen derived methods or one specification.
 */
interface DecisionRepository : JpaRepository<Decision, Long>, JpaSpecificationExecutor<Decision>

interface CommentRepository : JpaRepository<Comment, Long>
