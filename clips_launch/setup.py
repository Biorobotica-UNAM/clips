from setuptools import setup
import os
from glob import glob

package_name = 'clips_launch'

setup(
    name=package_name,
    version='0.0.0',
    packages=[],
    py_modules=[],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # Incluir todos los archivos launch
        (os.path.join('share', package_name, 'launch'), 
         glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='sergio',
    maintainer_email='sergio@email.com',
    description='Launch files for robot system',
    license='Apache-2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
        ],
    },
)