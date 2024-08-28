#!/bin/bash
# Generate a random quirky password
length=12
chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+'
password=$(cat /dev/urandom | tr -dc "$chars" | fold -w $length | head -n 1)
echo "Your quirky password is: $password"