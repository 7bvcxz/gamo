package `in`.gamo.server

import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The API's behaviour, against an in-memory database so `mvn test` needs nothing
 * running.
 *
 * What is worth pinning here is not that Spring can save a row. It is the rules
 * this API is supposed to enforce and that a caller -- a browser, a shell, me --
 * could otherwise violate quietly: that there are exactly two authors, that a
 * thread stays in order, and that an unknown value is refused rather than
 * defaulted. A comment filed as HUMAN because "claude" was spelled the wrong way
 * is worse than a rejected request, because nobody finds it later.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DecisionApiTest {

    @Autowired lateinit var mvc: MockMvc
    @Autowired lateinit var json: ObjectMapper

    private fun body(map: Map<String, Any?>) = json.writeValueAsString(map)

    private fun createDecision(
        title: String = "제목",
        extra: Map<String, Any?> = emptyMap(),
    ): Long {
        val response = mvc.perform(
            post("/api/gamo/v1/decisions")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(mapOf("title" to title) + extra)),
        ).andExpect(status().isOk).andReturn().response.contentAsString
        return json.readTree(response).get("id").asLong()
    }

    @Test
    fun `creates reads updates and deletes`() {
        val id = createDecision("하루 길이", mapOf("body" to "3분인가", "priority" to "P0"))

        mvc.perform(get("/api/gamo/v1/decisions/$id"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("하루 길이"))
            .andExpect(jsonPath("$.priority").value("P0"))
            // Not supplied, so it has to be the honest default rather than
            // whatever the first status in the enum happens to be.
            .andExpect(jsonPath("$.status").value("OPEN"))

        mvc.perform(
            patch("/api/gamo/v1/decisions/$id")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(mapOf("status" to "DECIDED", "outcome" to "길게 간다"))),
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("DECIDED"))
            .andExpect(jsonPath("$.outcome").value("길게 간다"))
            // A PATCH carries only what changed; everything else survives it.
            .andExpect(jsonPath("$.title").value("하루 길이"))
            .andExpect(jsonPath("$.body").value("3분인가"))

        mvc.perform(delete("/api/gamo/v1/decisions/$id")).andExpect(status().isOk)
        mvc.perform(get("/api/gamo/v1/decisions/$id")).andExpect(status().isNotFound)
    }

    @Test
    fun `a title is required and cannot be blanked`() {
        mvc.perform(
            post("/api/gamo/v1/decisions")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(mapOf("body" to "제목이 없다"))),
        ).andExpect(status().isBadRequest)

        val id = createDecision()
        mvc.perform(
            patch("/api/gamo/v1/decisions/$id")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(mapOf("title" to "   "))),
        ).andExpect(status().isBadRequest)
    }

    @Test
    fun `there are exactly two authors`() {
        val id = createDecision()
        for (author in listOf("HUMAN", "CLAUDE", "human", "claude")) {
            mvc.perform(
                post("/api/gamo/v1/decisions/$id/comments")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(body(mapOf("author" to author, "body" to "ok"))),
            ).andExpect(status().isOk)
        }
        // Anything else is refused rather than filed as a default. These are the
        // names a person would actually type by mistake.
        for (author in listOf("merti", "user", "assistant", "Claude Code", "", null)) {
            mvc.perform(
                post("/api/gamo/v1/decisions/$id/comments")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(body(mapOf("author" to author, "body" to "x"))),
            ).andExpect(status().isBadRequest)
        }
        mvc.perform(
            post("/api/gamo/v1/decisions/$id/comments")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(mapOf("author" to "HUMAN", "body" to "  "))),
        ).andExpect(status().isBadRequest)
    }

    @Test
    fun `a thread keeps the order it was written in`() {
        val id = createDecision()
        val said = listOf(
            "HUMAN" to "타일 원복해줘",
            "CLAUDE" to "되돌렸습니다",
            "HUMAN" to "좋아",
            "CLAUDE" to "다음은 무엇을",
        )
        for ((author, text) in said) {
            mvc.perform(
                post("/api/gamo/v1/decisions/$id/comments")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(body(mapOf("author" to author, "body" to text))),
            ).andExpect(status().isOk)
        }
        val response = mvc.perform(get("/api/gamo/v1/decisions/$id"))
            .andExpect(status().isOk).andReturn().response.contentAsString
        val comments = json.readTree(response).get("comments")
        assertEquals(said.size, comments.size())
        // Written in one burst, so several share a timestamp to the millisecond.
        // Ordering by time alone would let those come back shuffled, which is
        // exactly the case a hand check would never notice.
        said.forEachIndexed { index, (author, text) ->
            assertEquals(author, comments[index].get("author").asText())
            assertEquals(text, comments[index].get("body").asText())
        }
    }

    @Test
    fun `a comment can be removed without taking its decision`() {
        val id = createDecision()
        val response = mvc.perform(
            post("/api/gamo/v1/decisions/$id/comments")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(mapOf("author" to "CLAUDE", "body" to "지울 것"))),
        ).andExpect(status().isOk).andReturn().response.contentAsString
        val commentId = json.readTree(response).get("comments")[0].get("id").asLong()

        mvc.perform(delete("/api/gamo/v1/decisions/$id/comments/$commentId"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.comments.length()").value(0))
        mvc.perform(get("/api/gamo/v1/decisions/$id")).andExpect(status().isOk)
        mvc.perform(delete("/api/gamo/v1/decisions/$id/comments/$commentId"))
            .andExpect(status().isNotFound)
    }

    @Test
    fun `deleting a decision takes its comments with it`() {
        val id = createDecision()
        mvc.perform(
            post("/api/gamo/v1/decisions/$id/comments")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(mapOf("author" to "HUMAN", "body" to "남으면 안 된다"))),
        ).andExpect(status().isOk)
        mvc.perform(delete("/api/gamo/v1/decisions/$id")).andExpect(status().isOk)
        mvc.perform(get("/api/gamo/v1/decisions/$id")).andExpect(status().isNotFound)
    }

    @Test
    fun `filters narrow the list and combine`() {
        createDecision("열린 P0", mapOf("priority" to "P0", "category" to "loop"))
        createDecision("닫힌 P0", mapOf("priority" to "P0", "status" to "DECIDED", "category" to "loop"))
        createDecision("열린 P2", mapOf("priority" to "P2", "category" to "art", "body" to "고양이"))

        fun titles(query: String): List<String> {
            val response = mvc.perform(get("/api/gamo/v1/decisions$query"))
                .andExpect(status().isOk).andReturn().response.contentAsString
            return json.readTree(response).get("items").map { it.get("title").asText() }
        }

        assertTrue(titles("?priority=P0").containsAll(listOf("열린 P0", "닫힌 P0")))
        assertTrue("열린 P2" !in titles("?priority=P0"))
        assertTrue(titles("?status=OPEN&priority=P0") == listOf("열린 P0"))
        assertTrue(titles("?category=art") == listOf("열린 P2"))
        // Free text reaches the body, not only the title.
        assertTrue(titles("?q=고양이") == listOf("열린 P2"))
        // Unknown values are a bad request, not an empty list -- an empty list
        // reads as "nothing matches" and hides the typo that caused it.
        mvc.perform(get("/api/gamo/v1/decisions?status=NOPE")).andExpect(status().isBadRequest)
        mvc.perform(get("/api/gamo/v1/decisions?priority=P9")).andExpect(status().isBadRequest)
    }

    @Test
    fun `the list leads with the most urgent`() {
        createDecision("나중", mapOf("priority" to "P3"))
        createDecision("먼저", mapOf("priority" to "P0"))
        createDecision("중간", mapOf("priority" to "P1"))
        val response = mvc.perform(get("/api/gamo/v1/decisions?q=먼저"))
            .andExpect(status().isOk).andReturn().response.contentAsString
        assertEquals("먼저", json.readTree(response).get("items")[0].get("title").asText())

        val all = mvc.perform(get("/api/gamo/v1/decisions"))
            .andExpect(status().isOk).andReturn().response.contentAsString
        val priorities = json.readTree(all).get("items").map { it.get("priority").asText() }
        assertEquals(priorities.sorted(), priorities, "우선순위 순으로 나온다: $priorities")
    }
}
