Custom Sakai Scripts
====================

## About

I wrote this collection of scripts to help my institution manage it's course creation and maintenance.

## Dependencies

	gem install Savon

- You could probably do this with soap4r but it's been depricated in Ruby 1.9 going forward, and even though it can be installed, Savon is just too easy to use.
- Many of the scripts assume access to the open source Longsight SOAP API.

## Use

- Scripts will either look for a file called 'data.csv' or the csv entered as an argument.
- The 'host', 'usr', and 'pwd' variables need to be filled out for your Sakai environment.
