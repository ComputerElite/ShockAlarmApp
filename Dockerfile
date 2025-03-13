### Start Build Enviroment
FROM debian:latest AS build-env

# Start Install Depends
RUN apt-get update
RUN apt-get install -y curl git unzip wget
# End Install Depends

# Start Define Variables
ARG FLUTTER_SDK=/usr/local/flutter
ARG FLUTTER_VERSION=3.29.1
ARG APP=/ShockAlarmApp
ARG SHOCK_VERSION=0.0.19
# End Define Variables



## Start Install Flutter
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_SDK

# Start Selected Flutter Version Install
RUN cd $FLUTTER_SDK && git fetch && git checkout $FLUTTER_VERSION
# End Selected Flutter Version Install

# Start add flutter to path
ENV PATH="$FLUTTER_SDK/bin:$FLUTTER_SDK/bin/cache/dart-sdk/bin:${PATH}"
# End add flutter to path

# Start run Flutter commands
RUN flutter doctor -v
# End run Flutter commands
## End install Flutter

# Start Download source code
RUN wget https://github.com/ComputerElite/ShockAlarmApp/archive/refs/tags/$SHOCK_VERSION.tar.gz
RUN tar xfvz $SHOCK_VERSION.tar.gz
RUN mv ShockAlarmApp-$SHOCK_VERSION ShockAlarmApp
RUN git config --global --add safe.directory $HOME/.cache/flutter_sdk
RUN git config --global --add safe.directory /root/development/flutter
RUN git config --global --add safe.directory $APP
# End Download source code

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
