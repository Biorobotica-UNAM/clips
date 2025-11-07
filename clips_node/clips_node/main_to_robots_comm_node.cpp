#include <rclcpp/rclcpp.hpp>
#include <std_msgs/msg/string.hpp>
#include <vector>
#include <string>
#include <thread>
#include <memory>
#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/split.hpp>

// Socket includes
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <signal.h>

#define TCPPORT 9002

using namespace std;
using namespace std::chrono_literals;

class RobotCommNode : public rclcpp::Node
{
public:
    RobotCommNode() : Node("main_to_robots_comm_node")
    {
        // Inicializar planes para 3 robots
        plans_.resize(3);
        
        // Suscriptor para recibir planes de CLIPS
        plan_sub_ = this->create_subscription<std_msgs::msg::String>(
            "/clips/results", 10,
            std::bind(&RobotCommNode::planCallback, this, std::placeholders::_1));
        
        RCLCPP_INFO(this->get_logger(), "Nodo de comunicación con robots inicializado");
        
        // Iniciar servidor TCP en un hilo separado
        server_thread_ = std::thread(&RobotCommNode::robotsConnection, this);
    }
    
    ~RobotCommNode()
    {
        if (server_thread_.joinable()) {
            server_thread_.join();
        }
        
        // Cerrar sockets
        if (server_socket_desc_ >= 0) {
            close(server_socket_desc_);
        }
        for (int client_socket : clients_) {
            if (client_socket >= 0) {
                close(client_socket);
            }
        }
    }

private:
    void planCallback(const std_msgs::msg::String::SharedPtr msg)
    {
        string plan_text = msg->data;
        RCLCPP_INFO(this->get_logger(), "Plan recibido: %s", plan_text.c_str());
        
        // Verificar si es un mensaje de plan completo
        if (plan_text.find("=== PLAN COMPLETO:") == string::npos) {
            RCLCPP_DEBUG(this->get_logger(), "Mensaje no es un plan completo, ignorando");
            return;
        }
        
        // Parsear el plan
        vector<string> lines;
        boost::algorithm::split(lines, plan_text, boost::algorithm::is_any_of("\n"));
        
        vector<string> temp_plan;
        int robot_plan = -1;
        
        for (const string& line : lines) {
            if (line.find("Paso") != string::npos) {
                // Es una línea de paso del plan
                vector<string> tokens;
                boost::algorithm::split(tokens, line, boost::algorithm::is_any_of(" "));
                
                if (tokens.size() >= 4) {
                    // Determinar el robot basado en el contenido
                    // Buscar "Festino", "Festina", o "Festine" en los tokens
                    for (size_t i = 0; i < tokens.size(); i++) {
                        if (tokens[i] == "Festino") {
                            robot_plan = 0;
                            break;
                        } else if (tokens[i] == "Festina") {
                            robot_plan = 1;
                            break;
                        } else if (tokens[i] == "Festine") {
                            robot_plan = 2;
                            break;
                        }
                    }
                    
                    // Reconstruir la instrucción (omitir "Paso X:" y el nombre del robot)
                    string instruction = "";
                    bool start_collecting = false;
                    for (size_t i = 0; i < tokens.size(); i++) {
                        if (start_collecting) {
                            instruction += tokens[i] + " ";
                        }
                        // Comenzar a recolectar después del número de paso
                        if (i >= 2 && tokens[i].find(":") != string::npos) {
                            start_collecting = true;
                        }
                    }
                    
                    if (!instruction.empty()) {
                        temp_plan.push_back(instruction);
                    }
                }
            }
        }
        
        // Asignar el plan al robot correspondiente
        if (robot_plan >= 0 && robot_plan < 3 && !temp_plan.empty()) {
            {
                lock_guard<mutex> lock(plans_mutex_);
                plans_[robot_plan].push_back(temp_plan);
            }
            
            string robot_names[] = {"Festino", "Festina", "Festine"};
            RCLCPP_INFO(this->get_logger(), "Plan asignado a %s con %zu pasos", 
                       robot_names[robot_plan].c_str(), temp_plan.size());
        } else {
            RCLCPP_WARN(this->get_logger(), "No se pudo asignar el plan a ningún robot");
        }
    }
    
    void robotsConnection()
    {
        int c;
        struct sockaddr_in server, client;
        server_socket_desc_ = socket(AF_INET, SOCK_STREAM, 0);
        if (server_socket_desc_ == -1) {
            RCLCPP_ERROR(this->get_logger(), "No se pudo crear el socket TCP");
            return;
        }
        
        // Configurar el socket
        int opt = 1;
        if (setsockopt(server_socket_desc_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
            RCLCPP_ERROR(this->get_logger(), "Error en setsockopt");
            close(server_socket_desc_);
            return;
        }
        
        // Preparar estructura sockaddr_in
        server.sin_family = AF_INET;
        server.sin_addr.s_addr = INADDR_ANY;
        server.sin_port = htons(TCPPORT);
        
        if (bind(server_socket_desc_, (struct sockaddr*)&server, sizeof(server)) < 0) {
            RCLCPP_ERROR(this->get_logger(), "Error en bind TCP");
            close(server_socket_desc_);
            return;
        }
        
        RCLCPP_INFO(this->get_logger(), "Bind TCP exitoso en puerto %d", TCPPORT);
        listen(server_socket_desc_, 3);
        
        c = sizeof(struct sockaddr_in);
        int robots_connected = 0;
        
        while (rclcpp::ok() && robots_connected < 3) {
            RCLCPP_INFO(this->get_logger(), "Esperando conexiones TCP de robots...");
            
            int client_socket = accept(server_socket_desc_, (struct sockaddr*)&client, (socklen_t*)&c);
            if (client_socket < 0) {
                RCLCPP_ERROR(this->get_logger(), "Conexión de robot fallida");
                continue;
            }
            
            RCLCPP_INFO(this->get_logger(), "Conexión aceptada de robot %d", robots_connected);
            clients_.push_back(client_socket);
            
            // Iniciar hilo para comunicación con el robot
            robot_threads_[robots_connected] = std::thread(
                &RobotCommNode::singleRobotCommunication, this, robots_connected, client_socket);
            
            robots_connected++;
        }
    }
    
    void singleRobotCommunication(int robot_no, int client_socket)
    {
        RCLCPP_INFO(this->get_logger(), "Atendiendo robot %d", robot_no);
        
        unsigned int read_size;
        unsigned int write_size;
        unsigned char buffer;
        
        int current_plan = -1;
        int instruction_counter = 0;
        
        string tmp_str = "";
        
        while (rclcpp::ok()) {
            read_size = recv(client_socket, &buffer, sizeof(unsigned char), 0);
            
            if (read_size <= 0) {
                RCLCPP_WARN(this->get_logger(), "Robot %d desconectado", robot_no);
                break;
            }
            
            ostringstream ss;
            tmp_str = "";
            
            switch (buffer) {
            case 'n':  // Solicitud de siguiente instrucción
                {
                    lock_guard<mutex> lock(plans_mutex_);
                    
                    if (plans_[robot_no].empty()) {
                        RCLCPP_DEBUG(this->get_logger(), "Robot %d: No hay plan asignado", robot_no);
                        ss << "NoPlanAssigned" << '\0';
                        write_size = write(client_socket, ss.str().c_str(), ss.str().size());
                        break;
                    } else {
                        if (current_plan == -1) {
                            current_plan = 0;
                            RCLCPP_DEBUG(this->get_logger(), "Robot %d: Primer plan asignado", robot_no);
                        }
                        
                        if (instruction_counter < plans_[robot_no][current_plan].size()) {
                            tmp_str = plans_[robot_no][current_plan][instruction_counter];
                            RCLCPP_INFO(this->get_logger(), "Robot %d: Enviando paso %d: %s", 
                                       robot_no, instruction_counter, tmp_str.c_str());
                            
                            ss << tmp_str << '\0';
                            write_size = write(client_socket, ss.str().c_str(), ss.str().size());
                            instruction_counter++;
                        } else {
                            if (plans_[robot_no].size() > (current_plan + 1)) {
                                current_plan++;
                                instruction_counter = 0;
                                RCLCPP_INFO(this->get_logger(), "Robot %d: Cambiando al siguiente plan", robot_no);
                                ss << "PlanFinished" << '\0';
                                write_size = write(client_socket, ss.str().c_str(), ss.str().size());
                            } else {
                                RCLCPP_INFO(this->get_logger(), "Robot %d: No hay más planes", robot_no);
                                ss << "NoPlanAssigned" << '\0';
                                write_size = write(client_socket, ss.str().c_str(), ss.str().size());
                            }
                        }
                    }
                }
                break;
                
            default:
                RCLCPP_WARN(this->get_logger(), "Robot %d: Comando desconocido: %c", robot_no, buffer);
                break;
            }
        }
        
        close(client_socket);
        RCLCPP_INFO(this->get_logger(), "Comunicación con robot %d terminada", robot_no);
    }
    
    // Variables miembro
    rclcpp::Subscription<std_msgs::msg::String>::SharedPtr plan_sub_;
    vector<vector<vector<string>>> plans_;  // plans_[robot][plan][step]
    mutex plans_mutex_;
    
    vector<int> clients_;
    array<thread, 3> robot_threads_;
    thread server_thread_;
    int server_socket_desc_ = -1;
};

// Manejo de señales para limpieza
void signalHandler(int signum)
{
    rclcpp::shutdown();
}

int main(int argc, char** argv)
{
    // Configurar manejo de señales
    signal(SIGINT, signalHandler);
    
    rclcpp::init(argc, argv);
    
    auto node = std::make_shared<RobotCommNode>();
    
    RCLCPP_INFO(node->get_logger(), "Iniciando nodo de comunicación principal con robots");
    
    try {
        rclcpp::spin(node);
    } catch (const std::exception& e) {
        RCLCPP_ERROR(node->get_logger(), "Excepción: %s", e.what());
    }
    
    rclcpp::shutdown();
    return 0;
}