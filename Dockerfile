### Start Build Enviroment
FROM debian:latest AS build-env

# Start Install Depends
RUN apt-get update
RUN apt-get install -y curl unzip git
# End Install Depends

# Start Define Variables
ARG APP=/ShockAlarmApp
#change to main for latest git version
ARG SHOCK_VERSION=main
# End Define Variables


# Start Download source code
RUN git clone https://github.com/ComputerElite/ShockAlarmApp.git --branch $SHOCK_VERSION
RUN git config --global --add safe.directory $HOME/.cache/flutter_sdk
RUN git config --global --add safe.directory /root/development/flutter
RUN git config --global --add safe.directory $APP
# End Download source code

# Start Flutter Install
RUN cd $APP/flutter && git submodule update --init --recursive
# End Flutter Install

# Start add flutter to path
ENV PATH="$APP/flutter/bin:$APP/flutter/bin/cache/dart-sdk/bin:${PATH}"
# End add flutter to path

# Start run Flutter commands
RUN flutter doctor -v
# End run Flutter commands
## End install Flutter

# Start Set Working Directory
WORKDIR $APP
# End Set Working Directory

# Start Build Of Flutter Web App
RUN flutter clean
RUN flutter pub get
RUN flutter build web
# Start Build Of Flutter Web App
### End Build Enviroment

## Start Base Image For Built Flutter App
# Start Grab Webserver
FROM nginx:latest
# End Grab Webserver

# Start Copy Of Built Flutter Web App
COPY --from=build-env /ShockAlarmApp/build/web /usr/share/nginx/html
# End Copy Of Built Flutter Web App

# Start Expose Port And Run Nginx
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
# Start Expose Port And Run Nginx
## End Base Image For Built Flutter App
