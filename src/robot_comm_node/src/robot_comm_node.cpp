#include <rclcpp/rclcpp.hpp>
#include <std_msgs/msg/string.hpp>

#include <signal.h>
#include <arpa/inet.h>
#include <thread>
#include <vector>
#include <string>
#include <sstream>
#include <iostream>

#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/split.hpp>

#define TCPPORT 9002
using namespace std;

class MainToRobotsCommNode : public rclcpp::Node {
public:
    MainToRobotsCommNode() : Node("main_to_robots_comm_node") {
        RCLCPP_INFO(this->get_logger(), "Nodo main_to_robots_comm_node iniciado");

        plan_sub_ = this->create_subscription<std_msgs::msg::String>(
            "/clips/results", 10,
            std::bind(&MainToRobotsCommNode::planCallback, this, std::placeholders::_1)
        );

        // Inicia servidor TCP en un hilo independiente
        tcp_thread_ = std::thread(&MainToRobotsCommNode::robots_connection, this);
    }

    ~MainToRobotsCommNode() {
        signal_handler(SIGINT);
    }

private:
    // Estructura: vector por robot, cada plan contiene lista de instrucciones
    std::vector<std::vector<std::vector<std::string>>> plans_{3};
    std::vector<int> clients_;
    int server_socket_desc_;
    std::thread tcp_thread_;
    std::thread robot_connection_threads_[3];
    rclcpp::Subscription<std_msgs::msg::String>::SharedPtr plan_sub_;

    // --------------------------
    // CALLBACK DEL TOPIC CLIPS
    // --------------------------
    void planCallback(const std_msgs::msg::String::SharedPtr msg) {
        std::string full_plan = msg->data;
        if (full_plan.empty()) return;

        RCLCPP_INFO(this->get_logger(), "Plan recibido: %s", full_plan.c_str());

        std::vector<std::string> lines;
        boost::split(lines, full_plan, boost::is_any_of("\n"));
        std::vector<std::string> temp_plan;
        std::vector<std::string> tokens;
        int robot_plan = -1;

        for (const string& line : lines) {
            if (line.find("Paso") != string::npos) {
                // Es una línea de paso del plan
                vector<string> tokens;
                boost::algorithm::split(tokens, line, boost::algorithm::is_any_of(" "));
                
                if (tokens.size() >= 4) {
                    // Determinar el robot basado en el contenido
                    for (size_t i = 0; i < tokens.size(); i++) {
                        // std::cout << "Token->" << tokens[i] << std::endl;
                        if (tokens[i] == "Justina") {
                            robot_plan = 0;
                            break;
                        } else if (tokens[i] == "Festina") {
                            robot_plan = 1;
                            break;
                        } else if (tokens[i] == "Festine") {
                            robot_plan = 2;
                            break;
                        }
                        else
                            robot_plan = -1;
                    }
                    
                    // Reconstruir la instrucción (omitir "Paso X:" y el nombre del robot)
                    string instruction = "";
                    bool start_collecting = false;
                    for (size_t i = 0; i < tokens.size(); i++) {                        
                        if (start_collecting) {
                            instruction += tokens[i] + " ";
                        }
                        // Comenzar a recolectar después del número de paso
                        if (i >= 1 && tokens[i].find(":") != string::npos) {
                            start_collecting = true;
                        }
                    }
                    if (!instruction.empty()) {
                        temp_plan.push_back(instruction);
                    }
                    // std::cout << "Plan->" << temp_plan << std::endl;
                }
            }
        }

        if (robot_plan >= 0 && !temp_plan.empty()) {
            plans_[robot_plan].push_back(temp_plan);
            RCLCPP_INFO(this->get_logger(), "Plan asignado a %s con %zu pasos.",
                        robot_name(robot_plan).c_str(), temp_plan.size());
        }
    }

    std::string robot_name(int id) {
        switch (id) {
            case 0: return "Justina";
            case 1: return "Festina";
            case 2: return "Festine";
            default: return "Unknown";
        }
    }

    // --------------------------
    // MANEJO DE TCP
    // --------------------------
    void robots_connection() {
        struct sockaddr_in server{}, client{};
        int c;
        server_socket_desc_ = socket(AF_INET, SOCK_STREAM, 0);
        if (server_socket_desc_ == -1) {
            RCLCPP_ERROR(this->get_logger(), "No se pudo crear el socket TCP.");
            return;
        }

        int opt = 1;
        setsockopt(server_socket_desc_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));


        server.sin_family = AF_INET;
        server.sin_addr.s_addr = INADDR_ANY;
        server.sin_port = htons(TCPPORT);

        if (bind(server_socket_desc_, (struct sockaddr *)&server, sizeof(server)) < 0) {
            perror("bind TCP failed");
            return;
        }

        listen(server_socket_desc_, 3);
        c = sizeof(struct sockaddr_in);
        int robots_connected = 0;

        RCLCPP_INFO(this->get_logger(), "Servidor TCP iniciado en puerto %d", TCPPORT);

        while (rclcpp::ok()) {
            RCLCPP_INFO(this->get_logger(), "Esperando conexiones de robots...");
            int client_sock = accept(server_socket_desc_, (struct sockaddr *)&client, (socklen_t *)&c);
            if (client_sock < 0) {
                perror("robot connection failed");
                continue;
            }

            RCLCPP_INFO(this->get_logger(), "Conexión aceptada para robot %d", robots_connected + 1);
            clients_.push_back(client_sock);
            robot_connection_threads_[robots_connected] =
                std::thread(&MainToRobotsCommNode::single_robot_communication, this, robots_connected, client_sock);
            robots_connected++;
        }
        close(server_socket_desc_);
    }

    // --------------------------
    // HILO INDIVIDUAL POR ROBOT
    // --------------------------
    void single_robot_communication(int robot_no, int client_socket) {
        RCLCPP_INFO(this->get_logger(), "Atendiendo robot %s", robot_name(robot_no).c_str());

        unsigned char buffer;
        int current_plan = -1;
        int instruction_counter = 0;

        while (rclcpp::ok()) {
            ssize_t read_size = recv(client_socket, &buffer, sizeof(unsigned char), 0);
            if (read_size <= 0) continue;

            std::ostringstream ss;
            std::string tmp_str;

            switch (buffer) {
                case 'n':
                    if (plans_[robot_no].empty()) {
                        ss << "NoPlanAssigned" << '\0';
                        write(client_socket, ss.str().c_str(), ss.str().size());
                        break;
                    }

                    if (current_plan == -1)
                        current_plan = 0;

                    if (instruction_counter < (int)plans_[robot_no][current_plan].size()) {
                        tmp_str = plans_[robot_no][current_plan][instruction_counter];
                        ss << tmp_str << '\0';
                        write(client_socket, ss.str().c_str(), ss.str().size());
                        instruction_counter++;
                    } else {
                        if ((int)plans_[robot_no].size() > current_plan + 1) {
                            current_plan++;
                            instruction_counter = 0;
                            ss << "PlanFinished" << '\0';
                            write(client_socket, ss.str().c_str(), ss.str().size());
                        } else {
                            ss << "NoPlanAssigned" << '\0';
                            write(client_socket, ss.str().c_str(), ss.str().size());
                        }
                    }
                    break;

                default:
                    break;
            }
        }
    }

    // --------------------------
    // MANEJO DE SEÑALES
    // --------------------------
    void signal_handler(int) {
        RCLCPP_INFO(this->get_logger(), "Cerrando sockets TCP...");
        close(server_socket_desc_);
        for (int client : clients_) {
            close(client);
        }
    }
};

// --------------------------
// MAIN
// --------------------------
int main(int argc, char **argv) {
    rclcpp::init(argc, argv);
    auto node = std::make_shared<MainToRobotsCommNode>();

    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}
