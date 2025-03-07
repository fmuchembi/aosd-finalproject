
server <- function(input, output, session) {
  
  # Project area
  project_area <- 'projects/ee-fmuchembi/assets/project_area'
  
  # Load the FC project control and ref areas once
  referenceFC <- ee$FeatureCollection("projects/ee-fmuchembi/assets/reference")
  activeFC <- ee$FeatureCollection("projects/ee-fmuchembi/assets/active-zone")
  
  # Load the Restoration Suitability Image
  restoration_suitability <- ee$Image("projects/ee-fmuchembi/assets/restoration_suitability_areas")
  
  # ---------- PRELOAD ALL DATA AT APP STARTUP ----------
  
  # Load asset folders and names once
  active_asset_folder <- 'projects/ee-fmuchembi/assets/active-zone'
  control_asset_folder <- 'projects/ee-fmuchembi/assets/reference'
  
  # Reactive value to track selected season
  observeEvent(input$selected_season, {
    # Update the global selected_season variable when user changes selection
    selected_season <<- input$selected_season
  })
  
  # List the 'name_1' values once
  active_names <- tryCatch({
    list_feature_collection_assets(active_asset_folder)
  }, error = function(e) {
    message("Error listing active names: ", e$message)
    return(character(0))
  })
  
  control_names <- tryCatch({
    list_feature_collection_assets(control_asset_folder)
  }, error = function(e) {
    message("Error listing control names: ", e$message)
    return(character(0))
  })
  
  # Find matching names once
  matched_names <- intersect(active_names, control_names)
  
  # Update the dropdown choices once
  updateSelectInput(session, "selected_name", choices = matched_names)
  
  # Pre-calculate all NPP data for all regions at startup
  npp_data <- reactiveVal()
  
  # Preload all MODIS LST data once
  modisLST <- ee$ImageCollection("MODIS/061/MOD11A2")$
    filterDate('2001-01-01', '2023-12-31')$
    select('LST_Day_1km')
  
  # Convert LST from Kelvin to Celsius once
  convertToCelsius <- function(img) {
    img$multiply(0.02)$subtract(273.15)$
      copyProperties(img, list('system:time_start'))
  }
  lstCelsius <- modisLST$map(convertToCelsius)
  
  # Process LST year by year once
  years_list <- 2001:2023
  annualLST_list <- list()
  
  for (year in years_list) {
    yearlyLST <- lstCelsius$
      filter(ee$Filter$calendarRange(year, year, 'year'))$
      mean()
    
    timeBand <- ee$Image$constant(year - 2000)$rename('year')
    
    result_img <- yearlyLST$
      addBands(timeBand)$
      set('year', year)$
      set('system:time_start', ee$Date$fromYMD(year, 6, 1))
    
    annualLST_list[[length(annualLST_list) + 1]] <- result_img
  }
  
  # Convert list to ImageCollection once
  annualLSTCollection <- ee$ImageCollection(annualLST_list)
  
  # Pre-calculate all LST data for all regions
  lst_data <- reactiveVal()
  
  # Preload all NPP assets once
  asset_folder <- 'projects/ee-fmuchembi/assets/jdi_npp_files'
  npp_assets <- tryCatch({
    list_npp_assets(asset_folder)
  }, error = function(e) {
    message("Error listing NPP assets: ", e$message)
    return(character(0))
  })
  
  # Pre-calculate intervention years once - with error handling to avoid crashing the app
  df_interventions <- tryCatch({
    data.frame(
      name = matched_names,
      intervention_year = c(2018, 2016, 2018, 2019, 2021, 2019, 2016, 2016, 2021, 2019, 2019, 2020, 2020)
    )
  }, error = function(e) {
    message("Error creating intervention dataframe: ", e$message)
    # Provide a fallback
    data.frame(
      name = matched_names,
      intervention_year = rep(2018, length(matched_names))
    )
  })
  
  # ---------- PRE-COMPUTE ALL DATA ----------
  
  # Create a progress notification
  progress <- shiny::Progress$new()
  progress$set(message = "Loading data for all regions...", value = 0)
  
  # Initialize storage for all data
  all_npp_data <- list()
  all_lst_data <- list()
  
  # Process all regions to preload data - with error handling wrapping the entire loop
  tryCatch({
    for (i in seq_along(matched_names)) {
      name <- matched_names[i]
      progress$set(value = i/length(matched_names), 
                   detail = paste("Processing region", i, "of", length(matched_names), "-", name))
      
      # Get NPP data for this region
      tryCatch({
        active_feature_collection <- ee$FeatureCollection(active_asset_folder)$filter(ee$Filter$eq('name_1', name))
        control_feature_collection <- ee$FeatureCollection(control_asset_folder)$filter(ee$Filter$eq('name_1', name))
        
        # Extract NPP data
        df_active <- extract_npp_data(active_feature_collection, 'active')
        df_control <- extract_npp_data(control_feature_collection, 'control')
        df_combined <- bind_rows(df_active, df_control)
        all_npp_data[[name]] <- df_combined
      }, error = function(e) {
        message(paste("Error processing NPP data for region:", name, "-", e$message))
      })
      
      # Get LST data for this region
      tryCatch({
        # Process reference data
        feature <- referenceFC$filter(ee$Filter$eq('name_1', name))$first()
        activeFeature <- activeFC$filter(ee$Filter$eq('name_1', name))$first()
        
        if (!is.null(feature) && !is.null(activeFeature)) {
          # Extract reference data
          extractReferenceData <- function(image) {
            mean <- image$reduceRegion(
              reducer = ee$Reducer$mean(),
              geometry = feature$geometry(),
              scale = 1000,
              maxPixels = 1e9
            )
            
            ee$Feature(
              NULL, 
              list(
                'LST' = mean$get('LST_Day_1km'),
                'year' = image$get('year'),
                'system:time_start' = image$get('system:time_start'),
                'zone' = 'Reference'
              )
            )
          }
          
          # Extract active data
          extractActiveData <- function(image) {
            mean <- image$reduceRegion(
              reducer = ee$Reducer$mean(),
              geometry = activeFeature$geometry(),
              scale = 1000,
              maxPixels = 1e9
            )
            
            ee$Feature(
              NULL, 
              list(
                'LST' = mean$get('LST_Day_1km'),
                'year' = image$get('year'),
                'system:time_start' = image$get('system:time_start'),
                'zone' = 'Active'
              )
            )
          }
          
          # Get reference and active data
          referenceValues <- annualLSTCollection$map(extractReferenceData)
          activeValues <- annualLSTCollection$map(extractActiveData)
          
          # Combine data
          combinedData <- referenceValues$merge(activeValues)
          
          # Extract data to R dataframe
          lst_list <- ee_utils_py_to_r(combinedData$aggregate_array("LST")$getInfo())
          zone_list <- ee_utils_py_to_r(combinedData$aggregate_array("zone")$getInfo())
          year_list <- ee_utils_py_to_r(combinedData$aggregate_array("year")$getInfo())
          
          # Create dataframe if data exists
          if (length(lst_list) > 0 && length(zone_list) > 0 && length(year_list) > 0) {
            combined_df <- data.frame(
              LST = as.numeric(unlist(lst_list)),
              zone = unlist(zone_list),
              year = as.numeric(unlist(year_list))
            )
            all_lst_data[[name]] <- combined_df
          }
        }
      }, error = function(e) {
        message(paste("Error processing LST data for region:", name, "-", e$message))
      })
    }
  }, error = function(e) {
    message("Critical error in data loading process: ", e$message)
  })
  
  # Store all data in reactive values
  npp_data(all_npp_data)
  lst_data(all_lst_data)
  
  # Close progress
  progress$close()
  
  # ---------- SERVER OUTPUTS ----------
  
  output$project_map <- renderLeaflet({
    map <- leaflet() %>%
      addProviderTiles("CartoDB.Positron", group = "CartoDB Light") %>%
      addProviderTiles("OpenStreetMap", group = "OpenStreetMap") %>%
      addProviderTiles("Esri.WorldImagery", group = "Satellite") 
    
    # Add restoration suitability layer to map
    observe({
      # Visualization parameters
      vis_params <- list(
        bands = "classification",
        min = 0,
        max = 1,
        palette = c('green', 'green')
      )
      
      # Try to add the layer with error handling
      tryCatch({
        # Get map ID
        map_id <- restoration_suitability$visualize(vis_params)$getMapId()
        
        # Generate tile URL
        ee_tile_url <- sprintf(
          "https://earthengine.googleapis.com/map/%s/{z}/{x}/{y}",
          map_id$mapid
        )
        
        # Add the layer to the existing map
        leafletProxy("project_map") %>%
          addTiles(
            urlTemplate = ee_tile_url,
            attribution = "Earth Engine/Restoration Suitability",
            options = tileOptions(opacity = 0.7),
            group = "Restoration Suitability"
          )
      }, error = function(e) {
        # Try alternative URL format if first one fails
        tryCatch({
          map_id <- restoration_suitability$getMapId(vis_params)
          ee_tile_url <- sprintf(
            "https://earthengine.googleapis.com/v1alpha/%s/tiles/{z}/{x}/{y}",
            map_id$mapid
          )
          
          leafletProxy("project_map") %>%
            addTiles(
              urlTemplate = ee_tile_url,
              attribution = "Earth Engine/Restoration Suitability",
              options = tileOptions(opacity = 0.7),
              group = "Restoration Suitability"
            )
        }, error = function(e2) {
          message(paste("Error adding restoration suitability layer:", e2$message))
        })
      })
    })
    
    # Project Area
    tryCatch({
      # Get project area as sf
      project_area_fc <- ee$FeatureCollection(project_area)
      project_area_sf <- rgee::ee_as_sf(project_area_fc)
      
      # Add to map
      map <- map %>%
        addPolygons(data = project_area_sf, 
                    color = "black", 
                    weight = 1.5, 
                    opacity = 1, 
                    fillOpacity = 0, 
                    label = "Project Area", 
                    group = "Project Area")
    }, error = function(e) {
      message(paste("Error processing project area:", e$message))
    })
    
    # Reference area zone 
    tryCatch({
      reference_area_fc <- referenceFC
      reference_area_sf <- rgee::ee_as_sf(reference_area_fc)
      
      reference_area_sf <- sf::st_collection_extract(reference_area_sf, "POLYGON")
      
      map <- map %>%
        addPolygons(data = reference_area_sf, 
                    color = "red", 
                    weight = 1.5, 
                    opacity = 1, 
                    fillOpacity = 0, 
                    label = "Reference Area", 
                    group = "Reference Area")
    }, error = function(e) {
      message(paste("Error processing reference area:", e$message))
    })
    
    # Active area zone 
    tryCatch({
      active_area_fc <- activeFC
      active_area_sf <- rgee::ee_as_sf(active_area_fc)
      
      active_area_sf <- sf::st_collection_extract(active_area_sf, "POLYGON")
      
      map <- map %>%
        addPolygons(data = active_area_sf, 
                    color = "blue", 
                    weight = 1.5, 
                    opacity = 1, 
                    fillOpacity = 0, 
                    label = "Active Area", 
                    group = "Active Area")
    }, error = function(e) {
      message(paste("Error processing project area:", e$message))
    })
    
    # Add scale bar and layers control
    map <- map %>%
      addLayersControl(
        baseGroups = c("CartoDB Light", "OpenStreetMap", "Satellite"),
        overlayGroups = c("Project Area", "Reference Area", "Active Area", "Restoration Suitability"),
        options = layersControlOptions(collapsed = FALSE)
      ) %>%
      setView(lng = 37.4, lat = -2.65, zoom = 10) %>%
      addScaleBar(position = "bottomleft") %>%
      
      htmlwidgets::onRender("
      function(el, x) {
        var map = this;
        setTimeout(function() {
          var foundBounds = false;
          map.eachLayer(function(layer) {
            if (layer.getBounds && !foundBounds) {
              map.fitBounds(layer.getBounds());
              foundBounds = true;
            }
          });
        }, 500);
      }
    ")
    
    map
  })
  
  #NPP
  
  output$npp_plot <- renderPlot({
    req(input$selected_name)
    name <- input$selected_name
    
    df_combined <- npp_data()[[name]]
    req(df_combined) 
    
    # Safely get intervention year
    intervention_year <- tryCatch({
      df_interventions$intervention_year[df_interventions$name == name]
    }, error = function(e) {
      message("Error getting intervention year: ", e$message)
      return(2018)  # Fallback value
    })
    
    ggplot(df_combined, aes(x = year, y = NPP, color = label, group = label)) +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      scale_color_manual(values = c("active" = "#3366FF", "control" = "#FF5733"),
                         labels = c("active" = "Active Zone", "control" = "Reference Zone")) +
      geom_vline(xintercept = intervention_year, color = "green", linewidth = 1, linetype = "dashed") +
      labs(
        title = paste0("Mean NPP (g/m^2) - ", name),
        subtitle = paste("Intervention Year:", intervention_year),
        x = "Year", 
        y = "NPP (g/m²)",
        color = "Zone Type"
      ) +
      theme_light()
  })
  
  #LST
  
  output$lst_plot <- renderPlot({
    req(input$selected_name)
    name <- input$selected_name
    
    combined_df <- lst_data()[[name]]
    req(combined_df) 
    
    # Safely get intervention year
    intervention_year <- tryCatch({
      df_interventions$intervention_year[df_interventions$name == name]
    }, error = function(e) {
      message("Error getting intervention year: ", e$message)
      return(2018)  # Fallback value
    })
    
    #plot
    ggplot(combined_df, aes(x=year, y=LST, color=zone, group=zone)) +
      geom_line(linewidth=1) +
      geom_point(size=3) +
      scale_color_manual(values=c("Reference"="blue", "Active"="red")) +
      geom_vline(xintercept = intervention_year, color = "green", linewidth = 1, linetype = "dashed") +
      labs(
        title = paste0(name, " - LST "),
        subtitle = paste("Intervention Year:", intervention_year),
        x = "Year",
        y = "LST (°C)"
      ) +
      theme_minimal()
  })
}














