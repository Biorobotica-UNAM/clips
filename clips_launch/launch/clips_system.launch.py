from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    
    # Nodo CLIPS (Python)
    clips_node = Node(
        package='clips_node',
        executable='clips_node',
        name='clips_node',
        output='screen'
    )
    
    # Servidor TCP (robot_comm_node)
    robot_comm_node = Node(
        package='robot_comm_node',
        executable='robot_comm_node',
        name='robot_comm_node',
        output='screen'
    )
    
    # Nodo con chatGPT (natural_to_clips)
    natural_to_clips = Node(
        package='clips_node',
        executable='natural_to_clips',
        name='natural_to_clips',
        output='screen'
    )
    
    return LaunchDescription([
        clips_node,
        robot_comm_node,
        natural_to_clips,
    ])