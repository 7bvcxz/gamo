package `in`.gamo.server.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Configuration
import org.springframework.web.servlet.config.annotation.CorsRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer

/**
 * Which origins may call this from a browser.
 *
 * A list rather than `*`, even though this server is not reachable from the
 * internet today: the day it goes behind the tunnel is not the day anyone will
 * remember there was a wildcard here.
 */
@Configuration
class WebConfig(
    @Value("\${gamo.cors-origins}") private val origins: String,
) : WebMvcConfigurer {
    override fun addCorsMappings(registry: CorsRegistry) {
        registry.addMapping("/api/**")
            .allowedOrigins(*origins.split(",").map(String::trim).filter(String::isNotEmpty).toTypedArray())
            .allowedMethods("GET", "POST", "PATCH", "DELETE", "OPTIONS")
            .allowedHeaders("*")
    }
}
