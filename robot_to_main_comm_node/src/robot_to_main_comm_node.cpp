#include <rclcpp/rclcpp.hpp>
#include <std_msgs/msg/string.hpp>
#include <std_srvs/srv/trigger.hpp>

#include <arpa/inet.h> 
#include <sys/socket.h>
#include <unistd.h>
#include <memory>
#include <string>

#define TCPPORT 9002
#define SERVER_IP "192.168.0.101"  // Cambia a la IP correcta

using namespace std;
using namespace std::chrono_literals;

class RobotToMainCommNode : public rclcpp::Node
{
public:
    RobotToMainCommNode() : Node("robot_to_main_comm_node")
    {
        // Conectar al servidor TCP
        if (!connectToServer()) {
            RCLCPP_ERROR(this->get_logger(), "No se pudo conectar al servidor TCP");
            return;
        }

        // Crear servicio para solicitar instrucciones
        service_ = this->create_service<std_srvs::srv::Trigger>(
            "/request_instruction",
            std::bind(&RobotToMainCommNode::handleInstructionRequest, this,
                     std::placeholders::_1, std::placeholders::_2));

        // Crear publicador para enviar instrucciones
        publisher_ = this->create_publisher<std_msgs::msg::String>("/instruction_msg", 10);

        RCLCPP_INFO(this->get_logger(), "Nodo robot_to_main_comm_node inicializado");
        RCLCPP_INFO(this->get_logger(), "Servicio /request_instruction disponible");
        RCLCPP_INFO(this->get_logger(), "Publicador /instruction_msg creado");
    }

    ~RobotToMainCommNode()
    {
        if (client_fd_ >= 0) {
            close(client_fd_);
        }
    }

private:
    bool connectToServer()
    {
        struct sockaddr_in serv_addr;
        
        // Crear socket
        if ((client_fd_ = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
            RCLCPP_ERROR(this->get_logger(), "Error creando socket");
            return false;
        }

        // Configurar servidor
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(TCPPORT);

        // Convertir dirección IP
        if (inet_pton(AF_INET, SERVER_IP, &serv_addr.sin_addr) <= 0) {
            RCLCPP_ERROR(this->get_logger(), "Dirección IP inválida o no soportada: %s", SERVER_IP);
            close(client_fd_);
            client_fd_ = -1;
            return false;
        }

        // Conectar al servidor
        int status = connect(client_fd_, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
        if (status < 0) {
            RCLCPP_ERROR(this->get_logger(), "Conexión fallida con el servidor %s:%d", SERVER_IP, TCPPORT);
            close(client_fd_);
            client_fd_ = -1;
            return false;
        }

        RCLCPP_INFO(this->get_logger(), "Conectado exitosamente al servidor %s:%d", SERVER_IP, TCPPORT);
        return true;
    }

    void handleInstructionRequest(
        const std::shared_ptr<std_srvs::srv::Trigger::Request> request,
        std::shared_ptr<std_srvs::srv::Trigger::Response> response)
    {
        (void)request;  // No se usa el request en este caso

        RCLCPP_INFO(this->get_logger(), "Solicitud de instrucción recibida");

        if (client_fd_ < 0) {
            response->success = false;
            response->message = "No hay conexión con el servidor TCP";
            RCLCPP_ERROR(this->get_logger(), "Intento de solicitud sin conexión TCP");
            return;
        }

        char buffer[256] = {0};
        int valread = 0;

        try {
            // Enviar solicitud de siguiente instrucción al servidor
            ssize_t bytes_sent = write(client_fd_, "n", 1);
            if (bytes_sent <= 0) {
                throw std::runtime_error("Error enviando solicitud al servidor");
            }

            RCLCPP_DEBUG(this->get_logger(), "Solicitud 'n' enviada al servidor");

            // Recibir respuesta del servidor
            valread = read(client_fd_, buffer, sizeof(buffer) - 1);
            if (valread <= 0) {
                throw std::runtime_error("Error recibiendo respuesta del servidor");
            }

            buffer[valread] = '\0';  // Asegurar terminación de string

            RCLCPP_INFO(this->get_logger(), "Instrucción recibida del servidor: %s", buffer);

            // Crear mensaje para publicar
            auto instruction_msg = std_msgs::msg::String();
            instruction_msg.data = std::string(buffer);

            // Publicar en el tópico
            publisher_->publish(instruction_msg);
            RCLCPP_DEBUG(this->get_logger(), "Instrucción publicada en /instruction_msg");

            // Configurar respuesta del servicio
            response->success = true;
            response->message = instruction_msg.data;

            RCLCPP_INFO(this->get_logger(), "Instrucción procesada exitosamente");

        } catch (const std::exception& e) {
            RCLCPP_ERROR(this->get_logger(), "Error en handleInstructionRequest: %s", e.what());
            response->success = false;
            response->message = std::string("Error: ") + e.what();
            
            // Intentar reconectar
            close(client_fd_);
            client_fd_ = -1;
            if (!connectToServer()) {
                RCLCPP_ERROR(this->get_logger(), "No se pudo reconectar al servidor");
            }
        }
    }

    // Variables miembro
    rclcpp::Service<std_srvs::srv::Trigger>::SharedPtr service_;
    rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
    int client_fd_ = -1;
};

int main(int argc, char** argv)
{
    rclcpp::init(argc, argv);
    
    auto node = std::make_shared<RobotToMainCommNode>();
    
    RCLCPP_INFO(node->get_logger(), "Iniciando nodo de comunicación robot->main");
    
    try {
        rclcpp::spin(node);
    } catch (const std::exception& e) {
        RCLCPP_ERROR(node->get_logger(), "Excepción en main: %s", e.what());
    }
    
    rclcpp::shutdown();
    return 0;
}
