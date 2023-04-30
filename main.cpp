#include <random>
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <fstream>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/random.hpp>
#include <ctime>
#include <cstdlib>
#include <cmath>

const unsigned int SCREEN_WIDTH = 1920;
const unsigned int SCREEN_HEIGHT = 1080;

bool vSync = true;

GLfloat vertices[] =
{
	-1.0f, -1.0f , 0.0f, 0.0f, 0.0f,
	-1.0f,  1.0f , 0.0f, 0.0f, 1.0f,
	 1.0f,  1.0f , 0.0f, 1.0f, 1.0f,
	 1.0f, -1.0f , 0.0f, 1.0f, 0.0f,
};

GLuint indices[] =
{
	0, 2, 1,
	0, 3, 2
};

GLchar *LoadShader(const std::string &file)
{
	std::ifstream shaderFile;
	long shaderFileLength;

	shaderFile.open(file);

	if (shaderFile.fail())
	{
		throw std::runtime_error("COULD NOT FIND SHADER FILE");
	}

	shaderFile.seekg(0, shaderFile.end);
	shaderFileLength = shaderFile.tellg();
	shaderFile.seekg(0, shaderFile.beg);

	GLchar *shaderCode = new GLchar[shaderFileLength + 1];
	shaderFile.read(shaderCode, shaderFileLength);

	shaderFile.close();

	shaderCode[shaderFileLength] = '\0';

	return shaderCode;
}

struct CameraData {
    glm::vec3 cam_o;
    glm::vec3 forward;
    glm::vec3 right;
    glm::vec3 up;
    float fov;
} camera;

void processInput(GLFWwindow *window)
{
    const float cameraSpeed = 0.05f; // adjust accordingly
    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) {
        camera.cam_o += cameraSpeed * camera.forward;
	}
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) {
		std::cout << "\nS";
        camera.cam_o -= cameraSpeed * camera.forward;
	}
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) {
        camera.cam_o -= glm::normalize(glm::cross(camera.forward, camera.up)) * cameraSpeed;
		std::cout << "\nA";
	}
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) {
        camera.cam_o += glm::normalize(glm::cross(camera.forward, camera.up)) * cameraSpeed;
		std::cout << "\nD";
	}
}

int main()
{
	camera.cam_o = glm::vec3(0.0f, 0.0f, -2.0f);
	camera.forward = glm::vec3(0.0f, 0.0f, -1.0f);
	camera.right = glm::vec3(1.0f, 0.0f, 0.0f);
	camera.up = glm::vec3(0.0f, 1.0f, 0.0f);
	camera.fov = glm::radians(90.0f);

	glfwInit();

	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 5);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

	GLFWwindow* window = glfwCreateWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Ray Marching", nullptr, nullptr);

	if (!window)
	{
		std::cout << "Failed to create the GLFW window\n";
		glfwTerminate();
	}

	glfwMakeContextCurrent(window);
	glfwSwapInterval(vSync);

	gladLoadGL();

	GLuint VAO, VBO, EBO;
	glCreateVertexArrays(1, &VAO);
	glCreateBuffers(1, &VBO);
	glCreateBuffers(1, &EBO);

	glNamedBufferData(VBO, sizeof(vertices), vertices, GL_STATIC_DRAW);
	glNamedBufferData(EBO, sizeof(indices), indices, GL_STATIC_DRAW);

	glEnableVertexArrayAttrib(VAO, 0);
	glVertexArrayAttribBinding(VAO, 0, 0);
	glVertexArrayAttribFormat(VAO, 0, 3, GL_FLOAT, GL_FALSE, 0);

	glEnableVertexArrayAttrib(VAO, 1);
	glVertexArrayAttribBinding(VAO, 1, 0);
	glVertexArrayAttribFormat(VAO, 1, 2, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat));

	glVertexArrayVertexBuffer(VAO, 0, VBO, 0, 5 * sizeof(GLfloat));
	glVertexArrayElementBuffer(VAO, EBO);

	GLuint screenTex;
	glCreateTextures(GL_TEXTURE_2D, 1, &screenTex);
	glTextureParameteri(screenTex, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(screenTex, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureParameteri(screenTex, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTextureParameteri(screenTex, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTextureStorage2D(screenTex, 1, GL_RGBA32F, SCREEN_WIDTH, SCREEN_HEIGHT);
	glBindImageTexture(0, screenTex, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

	const GLchar *vertCode = LoadShader("../shader_files/shader.vert");
	const GLchar *fragCode = LoadShader("../shader_files/shader.frag");
	const GLchar *computeCode = LoadShader("../shader_files/Schwarzschild.glsl");

	GLuint screenVertexShader = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(screenVertexShader, 1, &vertCode, NULL);
	glCompileShader(screenVertexShader);

	GLuint screenFragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(screenFragmentShader, 1, &fragCode, NULL);
	glCompileShader(screenFragmentShader);

	GLuint screenShaderProgram = glCreateProgram();
	glAttachShader(screenShaderProgram, screenVertexShader);
	glAttachShader(screenShaderProgram, screenFragmentShader);
	glLinkProgram(screenShaderProgram);

	GLuint computeShader = glCreateShader(GL_COMPUTE_SHADER);
	glShaderSource(computeShader, 1, &computeCode, NULL);
	glCompileShader(computeShader);

	GLuint computeProgram = glCreateProgram();
	glAttachShader(computeProgram, computeShader);
	glLinkProgram(computeProgram);

	//camera ubo
	unsigned int uboCameraBlock;
	glGenBuffers(1, &uboCameraBlock);
	glBindBuffer(GL_UNIFORM_BUFFER, uboCameraBlock);
	glBufferData(GL_UNIFORM_BUFFER, sizeof(CameraData), NULL, GL_STATIC_DRAW);
	glBindBuffer(GL_UNIFORM_BUFFER, 1);

	glBindBufferBase(GL_UNIFORM_BUFFER, 1, uboCameraBlock); 


	while (!glfwWindowShouldClose(window))
	{
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);  

		processInput(window);
        glBindBuffer(GL_UNIFORM_BUFFER, uboCameraBlock);
		glBindBufferBase(GL_UNIFORM_BUFFER, 1, uboCameraBlock);
		glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(CameraData), &camera);

		glUseProgram(computeProgram);
		glDispatchCompute(std::ceil(SCREEN_WIDTH / 8), std::ceil(SCREEN_HEIGHT / 4), 1);
		glMemoryBarrier(GL_ALL_BARRIER_BITS);

		glUseProgram(screenShaderProgram);
		glBindTextureUnit(0, screenTex);
		glUniform1i(glGetUniformLocation(screenShaderProgram, "screen"), 0);
		glBindVertexArray(VAO);
		glDrawElements(GL_TRIANGLES, sizeof(indices) / sizeof(indices[0]), GL_UNSIGNED_INT, 0);

		glfwSwapBuffers(window);
		glfwPollEvents();
	}


	glDeleteShader(screenVertexShader);
	glDeleteShader(screenFragmentShader);

	glfwDestroyWindow(window);
	glfwTerminate();
}
