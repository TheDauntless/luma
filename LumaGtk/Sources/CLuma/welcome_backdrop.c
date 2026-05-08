#include "include/CLuma.h"

#include <gtk/gtk.h>
#include <epoxy/gl.h>
#include <stdint.h>
#include <stdlib.h>

#define LUMA_BACKDROP_DATA_KEY "luma-welcome-backdrop"

typedef struct {
    GLuint program;
    GLuint vao;
    GLuint vbo;
    GLint loc_resolution;
    GLint loc_time;
    GLint loc_scheme;
    gint64 start_us;
    guint tick_id;
    gboolean dark;
} LumaWelcomeBackdrop;

static const char *backdrop_vertex_src =
    "#version 150 core\n"
    "in vec2 a_pos;\n"
    "out vec2 v_uv;\n"
    "void main() {\n"
    "    v_uv = a_pos * 0.5 + 0.5;\n"
    "    gl_Position = vec4(a_pos, 0.0, 1.0);\n"
    "}\n";

static const char *backdrop_fragment_src =
    "#version 150 core\n"
    "in vec2 v_uv;\n"
    "out vec4 frag_color;\n"
    "uniform vec2 u_resolution;\n"
    "uniform float u_time;\n"
    "uniform float u_scheme;\n"
    "const vec3 CORAL      = vec3(0.937, 0.392, 0.337);\n"
    "const vec3 CORAL_DEEP = vec3(0.820, 0.290, 0.235);\n"
    "const vec3 PLUM       = vec3(0.369, 0.298, 0.353);\n"
    "const vec3 LIGHT_TOP  = vec3(1.000, 1.000, 0.998);\n"
    "const vec3 LIGHT_BOT  = vec3(0.988, 0.982, 0.974);\n"
    "const vec3 DARK_TOP   = vec3(0.155, 0.115, 0.140);\n"
    "const vec3 DARK_BOT   = vec3(0.075, 0.050, 0.065);\n"
    "float seed(int i, float k) {\n"
    "    return fract(sin(float(i) * k) * 43758.5453);\n"
    "}\n"
    "void main() {\n"
    "    float aspect = u_resolution.x / max(u_resolution.y, 1.0);\n"
    "    vec2 p = v_uv * 2.0 - 1.0;\n"
    "    p.x *= aspect;\n"
    "    vec3 lightColor = mix(LIGHT_BOT, LIGHT_TOP, v_uv.y);\n"
    "    vec3 darkColor  = mix(DARK_BOT,  DARK_TOP,  v_uv.y);\n"
    "    const int NUM = 22;\n"
    "    for (int i = 0; i < NUM; ++i) {\n"
    "        float s1 = seed(i, 12.93);\n"
    "        float s2 = seed(i, 78.23);\n"
    "        float s3 = seed(i,  5.41);\n"
    "        float s4 = seed(i, 91.71);\n"
    "        float speed = 0.018 + 0.030 * s1;\n"
    "        float life = fract(u_time * speed + s2);\n"
    "        float xBase = (-1.0 + 2.0 * s3) * aspect;\n"
    "        float xWobble = 0.04 + 0.10 * s4;\n"
    "        float x = xBase + xWobble * sin(u_time * (0.10 + 0.18 * s1) + s2 * 6.2832);\n"
    "        float y = -1.18 + life * 2.36;\n"
    "        float coreR = 0.006 + 0.007 * s4;\n"
    "        float haloR = 0.060 + 0.090 * s1;\n"
    "        float r = length(vec2(x, y) - p);\n"
    "        float core = 1.0 - smoothstep(0.0, coreR, r);\n"
    "        float halo = pow(1.0 - smoothstep(0.0, haloR, r), 2.2);\n"
    "        float fade = smoothstep(0.0, 0.18, life) * (1.0 - smoothstep(0.82, 1.0, life));\n"
    "        bool isPlum = s4 > 0.80;\n"
    "        vec3 lightHue  = isPlum ? PLUM : CORAL_DEEP;\n"
    "        vec3 lightHalo = isPlum ? PLUM : CORAL;\n"
    "        lightColor = mix(lightColor, lightHue, core * fade * 0.70);\n"
    "        lightColor = mix(lightColor, lightHalo, halo * fade * 0.32);\n"
    "        vec3 darkHue = isPlum ? mix(PLUM, CORAL, 0.55) : CORAL;\n"
    "        darkColor += darkHue * core * fade * 0.95;\n"
    "        darkColor += darkHue * halo * fade * 0.35;\n"
    "    }\n"
    "    float ribY = 0.45 + 0.18 * sin(u_time * 0.025);\n"
    "    float ribX = sin(p.x * 1.1 + u_time * 0.018);\n"
    "    float ribDist = (p.y - ribY) + 0.06 * ribX;\n"
    "    float ribbon = exp(-ribDist * ribDist * 32.0);\n"
    "    lightColor += CORAL * ribbon * 0.05;\n"
    "    darkColor  += CORAL * ribbon * 0.12;\n"
    "    float grain = fract(sin(dot(v_uv * u_resolution, vec2(12.9898, 78.233))) * 43758.5453);\n"
    "    lightColor += (grain - 0.5) * 0.008;\n"
    "    darkColor  += (grain - 0.5) * 0.012;\n"
    "    float vignette = smoothstep(1.60, 0.45, length(p * vec2(0.85, 1.0)));\n"
    "    lightColor *= mix(0.96, 1.0, vignette);\n"
    "    darkColor  *= mix(0.65, 1.0, vignette);\n"
    "    vec3 color = mix(darkColor, lightColor, u_scheme);\n"
    "    frag_color = vec4(color, 1.0);\n"
    "}\n";

static GLuint
compile_shader(GLenum kind, const char *src)
{
    GLuint shader = glCreateShader(kind);
    glShaderSource(shader, 1, &src, NULL);
    glCompileShader(shader);
    GLint ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetShaderInfoLog(shader, sizeof log, NULL, log);
        g_warning("luma welcome backdrop: shader compile failed: %s", log);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

static GLuint
link_program(void)
{
    GLuint vs = compile_shader(GL_VERTEX_SHADER, backdrop_vertex_src);
    GLuint fs = compile_shader(GL_FRAGMENT_SHADER, backdrop_fragment_src);
    if (vs == 0 || fs == 0) {
        if (vs != 0) glDeleteShader(vs);
        if (fs != 0) glDeleteShader(fs);
        return 0;
    }
    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glBindAttribLocation(program, 0, "a_pos");
    glLinkProgram(program);
    glDetachShader(program, vs);
    glDetachShader(program, fs);
    glDeleteShader(vs);
    glDeleteShader(fs);
    GLint ok = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetProgramInfoLog(program, sizeof log, NULL, log);
        g_warning("luma welcome backdrop: program link failed: %s", log);
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

static LumaWelcomeBackdrop *
ctx_for(GtkWidget *widget)
{
    return g_object_get_data(G_OBJECT(widget), LUMA_BACKDROP_DATA_KEY);
}

static void
on_realize(GtkGLArea *area, gpointer user_data)
{
    (void)user_data;
    LumaWelcomeBackdrop *self = ctx_for(GTK_WIDGET(area));
    if (self == NULL)
        return;
    gtk_gl_area_make_current(area);
    if (gtk_gl_area_get_error(area) != NULL)
        return;

    self->program = link_program();
    if (self->program == 0)
        return;
    self->loc_resolution = glGetUniformLocation(self->program, "u_resolution");
    self->loc_time = glGetUniformLocation(self->program, "u_time");
    self->loc_scheme = glGetUniformLocation(self->program, "u_scheme");

    static const float quad[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };

    glGenVertexArrays(1, &self->vao);
    glBindVertexArray(self->vao);
    glGenBuffers(1, &self->vbo);
    glBindBuffer(GL_ARRAY_BUFFER, self->vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof quad, quad, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glBindVertexArray(0);

    self->start_us = g_get_monotonic_time();
}

static void
on_unrealize(GtkGLArea *area, gpointer user_data)
{
    (void)user_data;
    LumaWelcomeBackdrop *self = ctx_for(GTK_WIDGET(area));
    if (self == NULL)
        return;
    gtk_gl_area_make_current(area);
    if (self->vbo != 0) { glDeleteBuffers(1, &self->vbo); self->vbo = 0; }
    if (self->vao != 0) { glDeleteVertexArrays(1, &self->vao); self->vao = 0; }
    if (self->program != 0) { glDeleteProgram(self->program); self->program = 0; }
}

static gboolean
on_render(GtkGLArea *area, GdkGLContext *context, gpointer user_data)
{
    (void)context;
    (void)user_data;
    LumaWelcomeBackdrop *self = ctx_for(GTK_WIDGET(area));
    if (self == NULL || self->program == 0)
        return FALSE;

    int width = gtk_widget_get_width(GTK_WIDGET(area));
    int height = gtk_widget_get_height(GTK_WIDGET(area));
    int scale = gtk_widget_get_scale_factor(GTK_WIDGET(area));
    float fb_w = (float)(width * scale);
    float fb_h = (float)(height * scale);

    float t = (float)((g_get_monotonic_time() - self->start_us) / 1000000.0);

    if (self->dark)
        glClearColor(0.075f, 0.050f, 0.065f, 1.0f);
    else
        glClearColor(0.994f, 0.991f, 0.986f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(self->program);
    glUniform2f(self->loc_resolution, fb_w, fb_h);
    glUniform1f(self->loc_time, t);
    glUniform1f(self->loc_scheme, self->dark ? 0.0f : 1.0f);
    glBindVertexArray(self->vao);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
    glUseProgram(0);
    return TRUE;
}

static gboolean
on_tick(GtkWidget *widget, GdkFrameClock *clock, gpointer user_data)
{
    (void)clock;
    (void)user_data;
    gtk_gl_area_queue_render(GTK_GL_AREA(widget));
    return G_SOURCE_CONTINUE;
}

void *
luma_welcome_backdrop_new(void)
{
    LumaWelcomeBackdrop *self = g_new0(LumaWelcomeBackdrop, 1);
    self->dark = FALSE;

    GtkWidget *area = gtk_gl_area_new();
    gtk_gl_area_set_has_depth_buffer(GTK_GL_AREA(area), FALSE);
    gtk_gl_area_set_has_stencil_buffer(GTK_GL_AREA(area), FALSE);
    gtk_gl_area_set_auto_render(GTK_GL_AREA(area), TRUE);

    g_object_set_data_full(G_OBJECT(area), LUMA_BACKDROP_DATA_KEY, self, g_free);

    g_signal_connect(area, "realize", G_CALLBACK(on_realize), NULL);
    g_signal_connect(area, "unrealize", G_CALLBACK(on_unrealize), NULL);
    g_signal_connect(area, "render", G_CALLBACK(on_render), NULL);

    self->tick_id = gtk_widget_add_tick_callback(area, on_tick, NULL, NULL);
    return area;
}

void
luma_welcome_backdrop_set_dark(void *widget, bool dark)
{
    if (widget == NULL)
        return;
    LumaWelcomeBackdrop *self = ctx_for(GTK_WIDGET(widget));
    if (self == NULL)
        return;
    self->dark = dark ? TRUE : FALSE;
    gtk_gl_area_queue_render(GTK_GL_AREA(widget));
}
