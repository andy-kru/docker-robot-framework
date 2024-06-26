FROM fedora:39

MAINTAINER Paul Podgorsek <ppodgorsek@users.noreply.github.com>
LABEL description Robot Framework in Docker.

# Set the Python dependencies' directory environment variable
ENV ROBOT_DEPENDENCY_DIR /opt/robotframework/dependencies

# Set the reports directory environment variable
ENV ROBOT_REPORTS_DIR /opt/robotframework/reports

# Set the tests directory environment variable
ENV ROBOT_TESTS_DIR /opt/robotframework/tests

# Set the working directory environment variable
ENV ROBOT_WORK_DIR /opt/robotframework/temp

# Setup X Window Virtual Framebuffer
ENV SCREEN_COLOUR_DEPTH 24
ENV SCREEN_HEIGHT 1080
ENV SCREEN_WIDTH 1920

# Setup the timezone to use, defaults to UTC
ENV TZ UTC

# Set number of threads for parallel execution
# By default, no parallelisation
ENV ROBOT_THREADS 1

# Define the default user who'll run the tests
ENV ROBOT_UID 1000
ENV ROBOT_GID 1000

# Dependency versions
ENV AWS_CLI_VERSION 1.32.103
ENV AXE_SELENIUM_LIBRARY_VERSION 2.1.6
ENV BROWSER_LIBRARY_VERSION 18.4.0
ENV CHROME_VERSION 124.0.6367.201
ENV DATABASE_LIBRARY_VERSION 1.4.4
ENV DATADRIVER_VERSION 1.11.1
ENV DATETIMETZ_VERSION 1.0.6
ENV MICROSOFT_EDGE_VERSION 124.0.2478.97
ENV FAKER_VERSION 5.0.0
ENV FIREFOX_VERSION 125.0
ENV FTP_LIBRARY_VERSION 1.9
ENV GECKO_DRIVER_VERSION v0.34.0
ENV IMAP_LIBRARY_VERSION 0.4.6
ENV PABOT_VERSION 2.18.0
ENV REQUESTS_VERSION 0.9.7
ENV ROBOT_FRAMEWORK_VERSION 7.0
ENV SELENIUM_LIBRARY_VERSION 6.3.0
ENV SSH_LIBRARY_VERSION 3.8.0
ENV XVFB_VERSION 1.20

# By default, no reports are uploaded to AWS S3
ENV AWS_UPLOAD_TO_S3 false

# Prepare binaries to be executed
COPY bin/chromedriver.sh /opt/robotframework/drivers/chromedriver
COPY bin/chrome.sh /opt/robotframework/bin/chrome
COPY bin/run-tests-in-virtual-screen.sh /opt/robotframework/bin/

# Install system dependencies
RUN dnf upgrade -y --refresh \
  && dnf install -y \
    dbus-glib \
    firefox-${FIREFOX_VERSION}* \
    gcc \
    gcc-c++ \
    npm \
    nodejs \
    python3-pip \
    python3-pyyaml \
    tzdata \
    xorg-x11-server-Xvfb-${XVFB_VERSION}* \
    dnf-plugins-core \
    git-all \
  && dnf clean all

# Install Chrome for Testing with dependencies
RUN dnf install -y \
    zip \

  # Exclude bash dependency to avoid conflicts
  && dnf deplist https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm | \
       grep provider | grep -v "bash" | \
       sort --unique | \
       awk '{print $2}' | \
       xargs dnf install --best --allowerasing --skip-broken -y \
  && wget -q "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip" \
  && wget -q "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip" \
  && unzip chrome-linux64.zip \
  && unzip chromedriver-linux64.zip \
  && mkdir -p /opt/chrome-for-testing/ \
  && mv chrome-linux64 /opt/chrome-for-testing \
  && mv chromedriver-linux64 /opt/chrome-for-testing \
  && rm chrome-linux64.zip chromedriver-linux64.zip \

  && dnf remove -y \
    zip \
  && dnf clean all

# Install Robot Framework and associated libraries
RUN pip3 install \
  --no-cache-dir \
  robotframework==$ROBOT_FRAMEWORK_VERSION \
  robotframework-browser==$BROWSER_LIBRARY_VERSION \
  robotframework-databaselibrary==$DATABASE_LIBRARY_VERSION \
  robotframework-datadriver==$DATADRIVER_VERSION \
  robotframework-datadriver[XLS] \
  robotframework-datetime-tz==$DATETIMETZ_VERSION \
  robotframework-faker==$FAKER_VERSION \
  robotframework-ftplibrary==$FTP_LIBRARY_VERSION \
  robotframework-imaplibrary2==$IMAP_LIBRARY_VERSION \
  robotframework-pabot==$PABOT_VERSION \
  robotframework-requests==$REQUESTS_VERSION \
  robotframework-seleniumlibrary==$SELENIUM_LIBRARY_VERSION \
  robotframework-sshlibrary==$SSH_LIBRARY_VERSION \
  axe-selenium-python==$AXE_SELENIUM_LIBRARY_VERSION \
  # Install awscli to be able to upload test reports to AWS S3
  awscli==$AWS_CLI_VERSION

# Install RPA Framework libraries
RUN pip3 install \
  --no-cache-dir \
  "git+https://github.com/andy-kru/rpaframework.git#egg=rpaframework&subdirectory=packages/main"

# Gecko drivers
RUN dnf install -y \
    wget \

  # Download Gecko drivers directly from the GitHub repository
  && wget -q "https://github.com/mozilla/geckodriver/releases/download/$GECKO_DRIVER_VERSION/geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz" \
  && tar xzf geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz \
  && mkdir -p /opt/robotframework/drivers/ \
  && mv geckodriver /opt/robotframework/drivers/geckodriver \
  && rm geckodriver-$GECKO_DRIVER_VERSION-linux64.tar.gz \

  && dnf remove -y \
    wget \
  && dnf clean all

# Install Microsoft Edge & webdriver
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc \
  && dnf config-manager --add-repo https://packages.microsoft.com/yumrepos/edge \
  && dnf install -y \
    microsoft-edge-stable-${MICROSOFT_EDGE_VERSION} \
    wget \
    zip \

  && wget -q "https://msedgedriver.azureedge.net/${MICROSOFT_EDGE_VERSION}/edgedriver_linux64.zip" \
  && unzip edgedriver_linux64.zip -d edge \
  && mv edge/msedgedriver /opt/robotframework/drivers/msedgedriver \
  && rm -Rf edgedriver_linux64.zip edge/ \

  # IMPORTANT: don't remove the wget package because it's a dependency of Microsoft Edge
  && dnf remove -y \
    zip \
  && dnf clean all

ENV PATH=/opt/microsoft/msedge:$PATH

# FIXME: Playright currently doesn't support relying on system browsers, which is why the `--skip-browsers` parameter cannot be used here.
RUN rfbrowser init

# Create the default report and work folders with the default user to avoid runtime issues
# These folders are writeable by anyone, to ensure the user can be changed on the command line.
RUN mkdir -p ${ROBOT_REPORTS_DIR} \
  && mkdir -p ${ROBOT_WORK_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_REPORTS_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_WORK_DIR} \
  && chmod ugo+w ${ROBOT_REPORTS_DIR} ${ROBOT_WORK_DIR}

# Allow any user to write logs
RUN chmod ugo+w /var/log \
  && chown ${ROBOT_UID}:${ROBOT_GID} /var/log

# Update system path
ENV PATH=/opt/robotframework/bin:/opt/robotframework/drivers:$PATH

# Ensure the directory for Python dependencies exists
RUN mkdir -p ${ROBOT_DEPENDENCY_DIR} \
  && chown ${ROBOT_UID}:${ROBOT_GID} ${ROBOT_DEPENDENCY_DIR} \
  && chmod 777 ${ROBOT_DEPENDENCY_DIR}

# Set up a volume for the generated reports
VOLUME ${ROBOT_REPORTS_DIR}

USER ${ROBOT_UID}:${ROBOT_GID}

# A dedicated work folder to allow for the creation of temporary files
WORKDIR ${ROBOT_WORK_DIR}

# Execute all robot tests
CMD ["run-tests-in-virtual-screen.sh"]
