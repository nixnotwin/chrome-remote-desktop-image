FROM ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive

# INSTALL FIREFOX AS A DEB AND NOT SNAP
COPY res/mozilla.preference.d /etc/apt/preferences.d/mozilla
COPY res/mozilla.list /etc/apt/sources.list.d/mozilla.list
COPY res/papirus-ubuntu-papirus-noble.sources /etc/apt/sources.list.d/papirus-ubuntu-papirus-noble.sources
COPY res/packages.mozilla.org.asc /etc/apt/keyrings/packages.mozilla.org.asc

# INSTALL SOURCES FOR CHROME REMOTE DESKTOP AND VSCODE
RUN apt-get update && apt-get upgrade --assume-yes
RUN apt-get --assume-yes install curl gpg wget
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN echo "deb [arch=amd64] http://packages.microsoft.com/repos/vscode stable main" | \
   tee /etc/apt/sources.list.d/vs-code.list
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
# INSTALL XFCE DESKTOP AND DEPENDENCIES
RUN apt-get update && apt-get upgrade --assume-yes
RUN apt-get install --assume-yes --fix-missing sudo wget apt-utils xvfb xfce4 xbase-clients \
    desktop-base vim xscreensaver google-chrome-stable psmisc xserver-xorg-video-dummy ffmpeg dialog python3-xdg \
    python3-packaging python3-psutil dbus-x11 papirus-icon-theme
RUN apt-get install libutempter0
RUN wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
RUN dpkg --install chrome-remote-desktop_current_amd64.deb
RUN apt-get install --assume-yes --fix-broken
RUN bash -c 'echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" > /etc/chrome-remote-desktop-session'

RUN apt-get install --assume-yes firefox
# ---------------------------------------------------------- 
# SPECIFY VARIABLES FOR SETTING UP CHROME REMOTE DESKTOP
#ARG USER=crduser
# use 6 digits at least
ENV PIN=123456
ENV CODE=4/xxx
ENV HOSTNAME=myvirtualdesktop
# ---------------------------------------------------------- 
# ADD USER TO THE SPECIFIED GROUPS
RUN adduser --disabled-password --gecos '' crduser
RUN mkhomedir_helper crduser
RUN adduser crduser sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN usermod -aG chrome-remote-desktop crduser 
USER crduser
WORKDIR /home/crduser
RUN sudo mkdir -p .config/chrome-remote-desktop
RUN sudo mkdir .config/chrome-remote-desktop/crashpad
RUN sudo chmod a+rx .config/chrome-remote-desktop
RUN echo "/usr/bin/pulseaudio --start" > .chrome-remote-desktop-session
RUN echo "startxfce4 :1030" >> .chrome-remote-desktop-session
RUN sudo chown -R crduser:crduser /home/crduser
CMD \
   DISPLAY= /opt/google/chrome-remote-desktop/start-host --code=$CODE --redirect-url="https://remotedesktop.google.com/_/oauthredirect" --name=$HOSTNAME --pin=$PIN ; \
   HOST_HASH=$(python3 -c "import hashlib,socket; print(hashlib.md5(socket.gethostname().encode()).hexdigest())") && \
   FILENAME=.config/chrome-remote-desktop/host#${HOST_HASH}.json && echo $FILENAME && \
   mv .config/chrome-remote-desktop/host#*.json $FILENAME ; \
   sudo service chrome-remote-desktop stop && \
   sudo service chrome-remote-desktop start && \
   echo $HOSTNAME && \
   sleep infinity & wait
