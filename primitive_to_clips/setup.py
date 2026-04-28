from setuptools import setup
import os
from glob import glob

package_name = "primitive_to_clips"

setup(
    name=package_name,
    version="0.0.1",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", ["resource/" + package_name]),
        ("share/" + package_name, ["package.xml"]),
        (os.path.join("share", package_name), glob("primitive_to_clips/*.yaml")),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="sergio",
    maintainer_email="sergio@todo.com",
    description="Convert primitives to CLIPS facts",
    license="Apache License 2.0",
    entry_points={
        "console_scripts": [
            "primitive_to_clips = primitive_to_clips.primitive_to_clips:main",
        ],
    },
)
