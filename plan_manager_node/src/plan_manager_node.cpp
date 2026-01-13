#include <rclcpp/rclcpp.hpp>
#include <std_msgs/msg/string.hpp>
#include <std_srvs/srv/trigger.hpp>

#include <memory>
#include <string>
#include <sstream>
#include <vector>
#include <map>

#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/split.hpp>

using namespace std;

class PlanManagerNode : public rclcpp::Node {
public:
    PlanManagerNode() : Node("plan_manager_node") {
        RCLCPP_INFO(this->get_logger(), "Nodo plan_manager_node iniciado");

        // Suscriptor para recibir planes completos
        plan_sub_ = this->create_subscription<std_msgs::msg::String>(
            "/clips/results", 10,
            std::bind(&PlanManagerNode::planCallback, this, std::placeholders::_1)
        );

        // Servicio para que los robots soliciten instrucciones
        service_ = this->create_service<std_srvs::srv::Trigger>(
            "/request_instruction",
            std::bind(&PlanManagerNode::handleInstructionRequest, this,
                     std::placeholders::_1, std::placeholders::_2));

        // Publicador para enviar instrucciones (opcional, si se quiere usar tópicos también)
        publisher_ = this->create_publisher<std_msgs::msg::String>("/instruction_msg", 10);

        // Inicializar estados de los robots
        initializeRobots();
    }

private:
    // Estructuras para almacenar planes
    struct RobotState {
        std::vector<std::vector<std::string>> plans;
        int current_plan;
        int instruction_counter;
        bool has_active_plan;
        
        RobotState() : current_plan(-1), instruction_counter(0), has_active_plan(false) {}
    };

    std::map<std::string, RobotState> robots_;
    std::map<std::string, std::string> robot_last_instruction_;
    
    rclcpp::Subscription<std_msgs::msg::String>::SharedPtr plan_sub_;
    rclcpp::Service<std_srvs::srv::Trigger>::SharedPtr service_;
    rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;

    // --------------------------
    // INICIALIZACIÓN DE ROBOTS
    // --------------------------
    void initializeRobots() {
        // Inicializar los tres robots
        robots_["Justina"] = RobotState();
        robots_["Festina"] = RobotState();
        robots_["Festine"] = RobotState();
        
        robot_last_instruction_["Justina"] = "";
        robot_last_instruction_["Festina"] = "";
        robot_last_instruction_["Festine"] = "";
        
        RCLCPP_INFO(this->get_logger(), "Robots inicializados: Justina, Festina, Festine");
    }

    // --------------------------
    // CALLBACK DEL TOPICO CLIPS
    // --------------------------
    void planCallback(const std_msgs::msg::String::SharedPtr msg) {
        std::string full_plan = msg->data;
        if (full_plan.empty()) {
            RCLCPP_WARN(this->get_logger(), "Plan vacío recibido");
            return;
        }

        RCLCPP_INFO(this->get_logger(), "Plan recibido: %s", full_plan.c_str());

        std::vector<std::string> lines;
        boost::split(lines, full_plan, boost::is_any_of("\n"));
        
        std::string current_robot = "";
        std::vector<std::string> temp_plan;

        for (const string& line : lines) {
            if (line.find("Paso") != string::npos) {
                // Es una línea de paso del plan
                vector<string> tokens;
                boost::algorithm::split(tokens, line, boost::algorithm::is_any_of(" "));
                
                if (tokens.size() >= 4) {
                    // Determinar el robot basado en el contenido
                    std::string robot_in_line = "";
                    for (size_t i = 0; i < tokens.size(); i++) {
                        if (tokens[i] == "Justina") {
                            robot_in_line = "Justina";
                            break;
                        } else if (tokens[i] == "Festina") {
                            robot_in_line = "Festina";
                            break;
                        } else if (tokens[i] == "Festine") {
                            robot_in_line = "Festine";
                            break;
                        }
                    }
                    
                    if (!robot_in_line.empty()) {
                        // Si cambió de robot, guardamos el plan anterior
                        if (!current_robot.empty() && current_robot != robot_in_line && !temp_plan.empty()) {
                            robots_[current_robot].plans.push_back(temp_plan);
                            RCLCPP_INFO(this->get_logger(), "Plan con %zu pasos asignado a %s",
                                       temp_plan.size(), current_robot.c_str());
                            temp_plan.clear();
                        }
                        current_robot = robot_in_line;
                        
                        // Reconstruir la instrucción (omitir "Paso X:" y el nombre del robot)
                        string instruction = "";
                        bool start_collecting = false;
                        for (size_t i = 0; i < tokens.size(); i++) {                        
                            if (start_collecting) {
                                instruction += tokens[i];
                                if (i < tokens.size() - 1) instruction += " ";
                            }
                            // Comenzar a recolectar después del número de paso
                            if (i >= 1 && tokens[i].find(":") != string::npos) {
                                start_collecting = true;
                            }
                        }
                        
                        // Eliminar el nombre del robot de la instrucción si está presente
                        size_t robot_pos = instruction.find(robot_in_line + " ");
                        if (robot_pos != string::npos) {
                            instruction.erase(robot_pos, robot_in_line.length() + 1);
                        }
                        
                        if (!instruction.empty()) {
                            temp_plan.push_back(instruction);
                        }
                    }
                }
            }
        }

        // Guardar el último plan si hay uno
        if (!current_robot.empty() && !temp_plan.empty()) {
            robots_[current_robot].plans.push_back(temp_plan);
            robots_[current_robot].current_plan = 0;
            robots_[current_robot].instruction_counter = 0;
            robots_[current_robot].has_active_plan = true;
            
            RCLCPP_INFO(this->get_logger(), "Plan final con %zu pasos asignado a %s",
                       temp_plan.size(), current_robot.c_str());
            RCLCPP_INFO(this->get_logger(), "Estado actual: %s tiene %zu planes",
                       current_robot.c_str(), robots_[current_robot].plans.size());
        }
    }

    // --------------------------
    // MANEJO DEL SERVICIO
    // --------------------------
    void handleInstructionRequest(
        const std::shared_ptr<std_srvs::srv::Trigger::Request> request,
        std::shared_ptr<std_srvs::srv::Trigger::Response> response) {
        
        (void)request;  // No se usa el request en este caso

        RCLCPP_INFO(this->get_logger(), "Solicitud de instrucción recibida");

        // Para simplificar, asumimos que el primer robot con plan activo es el que solicita
        // En un sistema real, deberías identificar qué robot está solicitando
        std::string robot_name = findRobotWithActivePlan();
        
        if (robot_name.empty()) {
            response->success = false;
            response->message = "NoPlanAssigned";
            RCLCPP_WARN(this->get_logger(), "No hay robots con plan activo");
            return;
        }

        RobotState& robot = robots_[robot_name];
        
        if (!robot.has_active_plan || robot.plans.empty()) {
            response->success = false;
            response->message = "NoPlanAssigned";
            RCLCPP_WARN(this->get_logger(), "Robot %s no tiene plan activo", robot_name.c_str());
            return;
        }

        // Verificar que el plan actual existe
        if (robot.current_plan < 0 || robot.current_plan >= (int)robot.plans.size()) {
            response->success = false;
            response->message = "PlanFinished";
            robot.has_active_plan = false;
            RCLCPP_INFO(this->get_logger(), "Robot %s ha completado todos los planes", robot_name.c_str());
            return;
        }

        // Obtener el plan actual
        std::vector<std::string>& current_plan = robot.plans[robot.current_plan];
        
        // Verificar si hay más instrucciones en el plan actual
        if (robot.instruction_counter < (int)current_plan.size()) {
            std::string instruction = current_plan[robot.instruction_counter];
            
            // Incrementar contador para la próxima vez
            robot.instruction_counter++;
            
            // Publicar también en el tópico (opcional)
            auto instruction_msg = std_msgs::msg::String();
            instruction_msg.data = robot_name.c_str() +std::string(" ")+ instruction;
            publisher_->publish(instruction_msg);
            
            response->success = true;
            response->message = robot_name.c_str() +std::string(" ")+ instruction;
            
            RCLCPP_INFO(this->get_logger(), "Instrucción enviada a %s: %s (paso %d/%zu)",
                       robot_name.c_str(), instruction.c_str(),
                       robot.instruction_counter, current_plan.size());
            
            // Verificar si se completó el plan actual
            if (robot.instruction_counter >= (int)current_plan.size()) {
                RCLCPP_INFO(this->get_logger(), "Plan %d completado para %s", 
                           robot.current_plan, robot_name.c_str());
                
                // Pasar al siguiente plan si existe
                robot.current_plan++;
                robot.instruction_counter = 0;
                
                if (robot.current_plan >= (int)robot.plans.size()) {
                    robot.has_active_plan = false;
                    RCLCPP_INFO(this->get_logger(), "Todos los planes completados para %s", robot_name.c_str());
                }
            }
        } else {
            // Esto no debería pasar si la lógica anterior es correcta
            response->success = false;
            response->message = "PlanFinished";
            RCLCPP_WARN(this->get_logger(), "Contador de instrucciones inválido para %s", robot_name.c_str());
        }
    }

    // --------------------------
    // FUNCIONES AUXILIARES
    // --------------------------
    std::string findRobotWithActivePlan() {
        // Busca el primer robot con plan activo
        // En una implementación real, necesitarías una manera de identificar qué robot está solicitando
        for (const auto& [name, state] : robots_) {
            if (state.has_active_plan && !state.plans.empty()) {
                return name;
            }
        }
        return "";
    }

    void printRobotStatus() {
        RCLCPP_INFO(this->get_logger(), "Estado de los robots:");
        for (const auto& [name, state] : robots_) {
            RCLCPP_INFO(this->get_logger(), "  %s: %zu planes, activo: %s, plan actual: %d, instrucción: %d",
                       name.c_str(), state.plans.size(), 
                       state.has_active_plan ? "sí" : "no",
                       state.current_plan, state.instruction_counter);
        }
    }
};

// --------------------------
// MAIN
// --------------------------
int main(int argc, char **argv) {
    rclcpp::init(argc, argv);
    auto node = std::make_shared<PlanManagerNode>();
    
    RCLCPP_INFO(node->get_logger(), "Plan Manager Node iniciado");
    RCLCPP_INFO(node->get_logger(), "Esperando planes en /clips/results");
    RCLCPP_INFO(node->get_logger(), "Servicio disponible en /request_instruction");
    
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}