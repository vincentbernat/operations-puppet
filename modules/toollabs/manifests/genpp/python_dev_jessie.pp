# Class: toollabs::genpp::python_dev_jessie
#
# This file was auto-generated by genpp.py using the following command:
# python.py
#
# Please do not edit manually!

class toollabs::genpp::python_dev_jessie {
    package { [
        'python-coverage',      # 3.7.1
        'python3-coverage',     # 3.7.1
        'python-dev',           # 2.7.9
        'python3-dev',          # 3.4.2
        'python-stdeb',         # 0.8.2
        'python3-stdeb',        # 0.8.2
    ]:
        ensure => latest,
    }
}