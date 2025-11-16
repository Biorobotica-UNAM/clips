#include "clips_client_cpp/clips_client_lib.hpp"
#include <thread>

ClipsClientLib::ClipsClientLib(std::shared_ptr<rclcpp::Node> node)
    : node_(node), external_node_(true)
{
    initialize_clients();
}

ClipsClientLib::ClipsClientLib(const std::string& node_name)
    : external_node_(false)
{
    rclcpp::init(0, nullptr); // Inicializar ROS2 si no está inicializado
    node_ = std::make_shared<rclcpp::Node>(node_name);
    initialize_clients();
}

void ClipsClientLib::initialize_clients()
{
    assert_fact_client_ = node_->create_client<custom_interfaces::srv::String>("clips/assert_fact");
    wait_for_services();
    
    RCLCPP_INFO(node_->get_logger(), "Biblioteca ClipsClientLib C++ inicializada");
}

void ClipsClientLib::wait_for_services()
{
    RCLCPP_INFO(node_->get_logger(), "Esperando servicios CLIPS...");
    
    while (!assert_fact_client_->wait_for_service(1s)) {
        if (!rclcpp::ok()) {
            throw std::runtime_error("Interrumpido mientras se esperaba por el servicio");
        }
        RCLCPP_INFO(node_->get_logger(), "Esperando servicio clips/assert_fact...");
    }
}

std::pair<bool, std::string> ClipsClientLib::assert_fact(const std::string& fact, double timeout_sec)
{
    try {
        auto request = std::make_shared<custom_interfaces::srv::String::Request>();
        request->data = fact;
        
        auto future = assert_fact_client_->async_send_request(request);
        
        // Esperar respuesta con timeout
        auto timeout = std::chrono::duration<double>(timeout_sec);
        auto start_time = node_->now();
        
        while (!future.valid() || future.wait_for(100ms) != std::future_status::ready) {
            if (node_->now() - start_time > rclcpp::Duration(timeout)) {
                return {false, "Timeout esperando respuesta del servicio"};
            }
            rclcpp::spin_some(node_);
        }
        
        if (future.valid()) {
            auto response = future.get();
            return {true, response->data};
        } else {
            return {false, "Respuesta futura no válida"};
        }
        
    } catch (const std::exception& e) {
        return {false, std::string("Error enviando hecho: ") + e.what()};
    }
}

rclcpp::Logger ClipsClientLib::get_logger() const
{
    return node_->get_logger();
}

ClipsClientLib::~ClipsClientLib()
{
    if (!external_node_ && rclcpp::ok()) {
        rclcpp::shutdown();
    }
}

// Implementación de funciones de conveniencia
std::pair<bool, std::string> send_fact_sync(const std::string& fact, double timeout_sec)
{
    ClipsClientLib client;
    return client.assert_fact(fact, timeout_sec);
}