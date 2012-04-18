Custom Sakai Scripts
====================

## About

I wrote this collection of scripts to help my institution manage it's course creation and maintenance.

## Dependencies

	gem install Savon

- You could probably do this with soap4r but it's been depricated in Ruby 1.9 going forward, and even though it can be installed, Savon is just too easy to use.
- Many of the scripts assume access to the open source Longsight Sakai API.

## Use

- Scripts will either look for a .csv defined in the code or the .csv entered as an argument.
- The 'host', 'soap_usr', and 'soap_pwd' variables need to be filled out for your Sakai environment.
- Column name/order for .csv is listed at the top of each script.