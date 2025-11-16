from setuptools import setup
import os
from glob import glob

package_name = 'clips_node'

setup(
    name=package_name,
    version='0.0.1',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'clips_rules'), glob('clips_node/clips_rules/*.clp')),
    ],
    install_requires=['setuptools', 'clipspy', 'rclpy'],
    zip_safe=True,
    maintainer='Sergio Cano',
    maintainer_email='sergio@example.com',
    description='Nodo ROS2 que ejecuta reglas CLIPS con clipspy.',
    license='MIT',
    entry_points={
        'console_scripts': [
            'clips_node = clips_node.clips_node:main',
            'clips_client_py = clips_node.clips_client:main',
        ],
    },
)

