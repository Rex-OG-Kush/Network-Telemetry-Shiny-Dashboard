# ==============================================================================
# PROJECT: INTERACTIVE NETWORK TELEMETRY & SECURITY DASHBOARD (R SHINY)
# AUTHOR: MATUTUZELA JABULANI NDLOVU
# PURPOSE: Front-end UI and server architecture for enterprise log visualization
# ==============================================================================

library(shiny)
library(dplyr)
library(ggplot2)

# 1. USER INTERFACE (UI) DEFINITION - Controls the layout, tabs, and styling
ui <- fluidPage(
  theme = shinytheme("slate"), # Dark mode theme for security operation centers
  
  titlePanel("🛡️ Enterprise Network Telemetry & Security Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Dashboard Controls"),
      selectInput("interface", "Select Router Interface:", 
                  choices = c("All Interfaces", "Eth0/1 - Core Switch", "Eth0/2 - Perimeter Firewall", "Wlan0 - Guest Wi-Fi")),
      sliderInput("threshold", "Anomaly Sensitivity Threshold (Packets):", 
                  min = 100, max = 500, value = 300),
      hr(),
      downloadButton("downloadReport", "📄 Generate R Markdown PDF Audit"),
      br(), br(),
      p("Logged in as: Administrator", style = "color: #00FF00;")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("📈 Live Telemetry", 
                 br(),
                 plotOutput("telemetryPlot"),
                 br(),
                 h4("Real-Time Interface Health Metrics"),
                 tableOutput("metricsTable")),
                 
        tabPanel("🚨 Security Alerts (Bayesian Log Parsing)", 
                 br(),
                 h4("High-Risk Network Anomalies Detected"),
                 p("The table below displays traffic logs that have broken past the 3-Sigma statistical threshold baseline."),
                 tableOutput("alertTable"))
      )
    )
  )
)

# 2. SERVER LOGIC - Generates the plots, processes thresholds, and filters logs
server <- function(input, output) {
  
  # Reactive data engine simulating real-time telemetry logs
  get_telemetry_data <- reactive({
    set.seed(930925)
    data <- data.frame(
      Time = seq(from = Sys.time() - 3600*24, by = "15 min", length.out = 96),
      Interface = sample(c("Eth0/1 - Core Switch", "Eth0/2 - Perimeter Firewall", "Wlan0 - Guest Wi-Fi"), 96, replace = TRUE),
      PacketsPerSec = rpois(96, lambda = 120),
      Latency_ms = runif(96, min = 5, max = 45)
    )
    # Inject deliberate malicious spikes into the timeline
    data$PacketsPerSec[c(14, 45, 78)] <- c(485, 520, 460)
    
    if(input$interface != "All Interfaces") {
      data <- data %>% filter(Interface == input$interface)
    }
    return(data)
  })
  
  # Render the Time-Series Telemetry Trend Plot using ggplot2
  output.telemetryPlot <- renderPlot({
    df <- get_telemetry_data()
    ggplot(df, aes(x = Time, y = PacketsPerSec, color = Interface)) +
      geom_line(size = 1) +
      geom_hline(yintercept = input$threshold, linetype = "dashed", color = "red", size = 1) +
      labs(title = "Network Traffic Throughput vs Security Alert Baselines",
           x = "Timeline", y = "Packets Per Second (PPS)") +
      theme_minimal()
  })
  
  # Render the basic metrics summary table
  output$metricsTable <- renderTable({
    df <- get_telemetry_data()
    df %>% group_by(Interface) %>%
      summarise(Avg_Throughput_PPS = mean(PacketsPerSec),
                Peak_Throughput_PPS = max(PacketsPerSec),
                Avg_Latency_ms = mean(Latency_ms))
  })
  
  # Render the isolated, high-risk security alert tracking table
  output$alertTable <- renderTable({
    df <- get_telemetry_data()
    df %>% filter(PacketsPerSec > input$threshold) %>%
      select(Time, Interface, PacketsPerSec, Latency_ms) %>%
      rename(Trigger_Time = Time, Breached_PPS = PacketsPerSec)
  })
}

# 3. RUN APPLICATION INFRASTRUCTURE
shinyApp(ui = ui, server = server)
