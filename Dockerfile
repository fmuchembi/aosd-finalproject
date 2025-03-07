# Base image
FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    wget \
    libgdal-dev \
    libproj-dev \
    libudunits2-dev \
    libgeos-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages with verbose output
RUN R -e "options(repos = c(CRAN = 'https://cran.rstudio.com/')); \
    install.packages('reticulate', dependencies = TRUE); \
    print('Reticulate package installed'); \
    install.packages('rgee', dependencies = TRUE); \
    print('rgee package installed'); \
    installed.packages()[,'Package']" \
    || (echo "ERROR: R package installation failed" && exit 1)

# Install miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /miniconda.sh && \
    bash /miniconda.sh -b -p /opt/miniconda && \
    rm /miniconda.sh

# Make miniconda available in PATH
ENV PATH="/opt/miniconda/bin:${PATH}"

# Create Python environment using the exact specification from your code
RUN /opt/miniconda/bin/conda create -y -p /opt/rgee python=3.9 && \
    /opt/miniconda/bin/conda install -y -p /opt/rgee -c conda-forge earthengine-api=0.1.370

# Install additional Python dependencies
RUN /opt/rgee/bin/pip install \
    numpy \
    pandas \
    google-api-python-client \
    oauth2client

# Configure R to use the right Python
RUN R -e "packageVersion('rgee'); \
    Sys.setenv(RETICULATE_PYTHON = '/opt/rgee/bin/python'); \
    library(reticulate); \
    py_config(); \
    library(rgee); \
    ee_install_set_pyenv(py_path = '/opt/rgee/bin/python', confirm = TRUE)" \
    || (echo "ERROR: Failed to set up rgee" && exit 1)

# Create directories for Shiny app
RUN mkdir -p /srv/shiny-server/data /srv/shiny-server/www

# Copy the required Shiny app files
COPY ui.R server.R global.R /srv/shiny-server/

# Copy the startup script
COPY start-app.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-app.sh

# Expose the Shiny port
EXPOSE 3838

# Run the wrapper script
CMD ["/usr/local/bin/start-app.sh"]
