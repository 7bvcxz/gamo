package `in`.gamo.server

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

/**
 * The gamo side-server.
 *
 * The site itself is a static export with no runtime -- deliberately, so that
 * Vercel, GitHub Pages and the nginx in deploy/ can serve byte-identical files.
 * This server sits beside it rather than inside it: the site never requires it
 * to render, and a page that wants live data asks for it and falls back to a
 * committed snapshot when nobody answers.
 *
 * It exists because decisions about the game need somewhere to live that is
 * neither a chat log nor a markdown file someone has to remember to edit.
 */
@SpringBootApplication
class GamoServerApplication

fun main(args: Array<String>) {
    runApplication<GamoServerApplication>(*args)
}
