# ISL MCLOUD WRAPPER

Wrapper written in Cython for the C-API from MCLOUD
[link to Git repository](https://github.com/ELITR/pv-platform-sample-connector)
## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. 

### Prerequisites


```
- Docker
```

### Installing

These two docker commands are building the Docker image and afterwards 
creating the Docker container:
```
$ docker build -t mcloud_wrapper .
$ docker run --name mlcoud -it mcloud_wrapper
```
After the container is created it directly jumps into the bash terminal from 
the container:

```
root@db3872174e68:/home/isl_mcloud_wrapper/src/src# 
```
### Usage
You can test an exemplary client implementation by import Client.so and executing the run method:
````
root@db3872174e68:/home/isl_mcloud_wrapper/src/src# python3
Python 3.6.7 (default, Nov 29 2019, 11:32:17) 
[GCC 8.2.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> from Client import run
>>> run()

````


## Authors

* **Siyar Yikmis** 
