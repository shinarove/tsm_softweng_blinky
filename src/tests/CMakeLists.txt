# file: Collect all files that need to be compiled. 
# You can use a GLOB function as shown here, or explicitly mention the specific files
#file(GLOB FILES *.c *.h)

# Need to include CTest on every CMakeLists.txt which is going to use tests
include(CTest)

set(THIS_LIBRARY_NAME srcTestsLib)

file(GLOB FILES
  *.c
)

# add_library: With this declaration, you express the intent to build a library. 
# The first argument is the name of the library, 
# the second argument are the files that will be compiled to create your library.
add_library(${THIS_LIBRARY_NAME} ${FILES})

# target_link_libraries: If you link with other libraries, list them here
target_link_libraries(
  ${THIS_LIBRARY_NAME}
  PRIVATE McuLib
  PRIVATE srcLib
  PRIVATE unityLib
)

# target_include_directories: Libraries need to publish their header files 
# so that you can import them in source code. This statement expresses where to find the files 
# - typically in an include directory of your projects.
target_include_directories(
  ${THIS_LIBRARY_NAME}
  PUBLIC
  .
)

#################################################################################
if (DEFINED ENV{PICO_SEGGER_IP})
  # Set PICO_SEGGER_IP to something linke "192.168.65.254" or "tunnel:801048148"
  # For using an IP, start on the host 'JLinkRemoteServerCL' (no arguments needed) and use its IP
  # For using a tunnel, you have to run the server on thost, e.g.:
  # JLinkRemoteServerCL -UseTunnel -TunnelBySN -select="801048148"
  set (JRUN_CTEST_COMMAND JRun --verbose --device RP2040_M0_0 --rtt -if SWD --pc off --sp off --ip "$ENV{PICO_SEGGER_IP}")
else()
  # Connect directly to the probe with USB
  set (JRUN_CTEST_COMMAND JRun --verbose --device RP2040_M0_0 --rtt -if SWD --pc off --sp off)
endif()

add_test(
  NAME Led_1
  COMMAND ${JRUN_CTEST_COMMAND} --args "Led_1" ${TEST_EXECUTABLE}
)

add_test(
  NAME Led_2
  COMMAND ${JRUN_CTEST_COMMAND} --args "Led_2" ${TEST_EXECUTABLE}
)

add_test( # will intentially fail, because no such test
  NAME Led_3
  COMMAND ${JRUN_CTEST_COMMAND} --args "Led_3" ${TEST_EXECUTABLE}
)

set_tests_properties(
  Led_1 Led_2 Led_3 
  PROPERTIES 
    TIMEOUT 30
)
