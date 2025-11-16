#ifndef CLIPS_CLIENT_LIB_HPP
#define CLIPS_CLIENT_LIB_HPP

#include <rclcpp/rclcpp.hpp>
#include <custom_interfaces/srv/string.hpp>
#include <std_srvs/srv/trigger.hpp>
#include <string>
#include <memory>
#include <chrono>
#include <utility>

using namespace std::chrono_literals;

class ClipsClientLib
{
public:
    /**
     * @brief Constructor que usa un nodo existente
     * @param node Puntero shared_ptr al nodo existente
     */
    explicit ClipsClientLib(std::shared_ptr<rclcpp::Node> node);
    
    /**
     * @brief Constructor que crea un nodo interno
     * @param node_name Nombre del nodo interno a crear
     */
    explicit ClipsClientLib(const std::string& node_name = "clips_client_lib");
    
    /**
     * @brief Envía un hecho a CLIPS
     * @param fact Hecho CLIPS a enviar
     * @param timeout_sec Tiempo máximo de espera en segundos
     * @return pair<bool, string> (éxito, mensaje de respuesta)
     */
    std::pair<bool, std::string> assert_fact(const std::string& fact, double timeout_sec = 10.0);    
    
    
    /**
     * @brief Obtiene el logger para logging personalizado
     * @return Logger del nodo
     */
    rclcpp::Logger get_logger() const;
    
    /**
     * @brief Destructor
     */
    ~ClipsClientLib();

private:
    void initialize_clients();
    void wait_for_services();
    
    std::shared_ptr<rclcpp::Node> node_;
    rclcpp::Client<custom_interfaces::srv::String>::SharedPtr assert_fact_client_;
    bool external_node_;
};

// Funciones de conveniencia para uso sincrónico
std::pair<bool, std::string> send_fact_sync(const std::string& fact, double timeout_sec = 10.0);

#endif // CLIPS_CLIENT_LIB_HPP