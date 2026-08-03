## [0.7.0] - 2026-08-03

### 🚀 Features

- *(home)* Emphasize zero-price plot band baseline (#29)
- *(home)* Render negative price segments in a distinct color (#30)
- *(settings)* Make the negative price color configurable (#31)
- *(home)* Extend the chart with forecast prices (#34)
- *(home)* Extend the list with forecast prices (#35)
- *(home)* Visually distinguish forecast prices (#36)
- *(home)* Improve historical charge chart legibility (#40)
- *(history)* Add screen with date-range presets (#48)
- *(home)* Color textual charges by unit rate (#51)
- *(history)* Color textual charges by unit rate (#52)
- *(home)* Replace best with contiguous window (#57)
- *(home)* Add today's summary card with comparisons (#60)
- *(common)* Add chart legend explaining color and line style (#63)
- *(common)* Add negative-price to chart legend (#67)
- *(settings)* Add section headers to settings cards (#78)
- *(settings)* Make threshold price values editable (#79)
- *(settings)* Scope each save button to its own card (#80)
- *(settings)* Use explicit range wording for thresholds (#81)
- *(settings)* De-emphasize about button (#82)
- *(settings)* Use a text button for grid supply point detection (#83)
- *(settings)* Add configurable tariff comparison rate (#84)
- *(settings)* Add configurable hours below threshold (#86)
- *(settings)* Add threshold ordering validation and restore defaults (#88)
- *(settings)* Add auto-select latest tariff checkbox (#89)

### 🐛 Bug Fixes

- *(forecast)* Type forecast charges as utc date times (#42)
- *(home)* Color historical charge chart with gradient (#47)
- *(home)* Size window cards to their content (#62)
- *(settings)* Add `TextOverflow.ellipsis` to prevent text from overflowing

### 💼 Other

- *(deps-dev)* Bump flutter_lints from 5.0.0 to 6.0.0
- *(deps)* Bump go_router from 15.1.2 to 17.3.0
- *(deps)* Bump cupertino_icons from 1.0.8 to 1.0.9
- *(deps)* Bump flex_color_picker from 3.7.1 to 3.8.0
- *(deps)* Bump geolocator from 14.0.1 to 14.0.2
- *(deps)* Bump intl from 0.20.2 to 0.20.3
- *(deps)* Bump provider from 6.1.5 to 6.1.5+1
- *(deps)* Bump shared_preferences from 2.5.3 to 2.5.5
- *(deps)* Bump url_launcher from 6.3.1 to 6.3.2
- *(deps)* Bump syncfusion_flutter_charts from 29.2.9 to 34.1.29

### 🚜 Refactor

- Collect historical agile octopus price data (#23)
- Collect historical neso generation data (#24)
- Build seasonal average lookup table (#25)
- *(forecast)* Add seasonal average lookup service (#33)
- Train price forecast model on historical data (#37)
- Export price forecast model to onnx (#38)
- *(forecast)* Bundle and load price forecast model (#43)
- *(forecast)* Replace seasonal naive forecast with inference (#44)
- *(forecast)* Migrate from onnxruntime to flutter_onnxruntime (#46)
- *(home)* Replace `HistoricalChargeCard` with `HistoricalChargeSummaryCard` (#56)
- *(home)* Scroll the screen as one continuous surface (#59)
- *(home)* Remove y-axis title from chart (#66)
- *(settings)* Move tariff comparison rate form field (#87)
- *(settings)* Move color stop defaults
- *(settings)* Move negative price sentinel
- *(welcome)* Reword repetitive intro copy (#92)
- *(welcome)* Rename save button to continue (#93)
- *(common)* Extract average value inc vat extension
- *(common)* Extract median value inc vat extension

### 📚 Documentation

- Add contributing guidelines
- Update readme
- Update contributing guidelines
- Update contributing guidelines

### 🧪 Testing

- Remove placeholder widget test

### ⚙️ Miscellaneous Tasks

- Add script output data to gitignore
- Add pull request workflow
## [0.6.0] - 2026-06-23

### 🚀 Features

- Add time period to chart trackball (#5)
- *(settings)* Add color stops form (#6)
- *(settings)* Add initial values to tariff form (#9)
- *(settings)* Add initial values to color stops form (#10)
- *(home)* Add day of week to historical charge chart x axis labels
- *(home)* Simplify historical charge scroll view date format

### 💼 Other

- Add octopus_energy_api_client package
- *(android)* Bump gradle and kotlin
- *(android)* Add file input stream import
- *(android)* Add properties import

### 🚜 Refactor

- Migrate octopus energy api client
- *(home)* Replace x axis crosses at with y axis plot band

### ⚙️ Miscellaneous Tasks

- Update license
- Add directives ordering linter rule
- Update copyright year
- Regenerate changelog using git-cliff
## [0.5.1] - 2025-10-01

### 💼 Other

- Add nominatim_api_client package

### 🚜 Refactor

- Migrate nominatim api client
## [0.5.0] - 2025-07-14

### 🚀 Features

- *(home)* Add grid view to home screen
- *(home)* Replace grid view with custom scroll view

### 🚜 Refactor

- *(common)* Replace vertical divider with background color
- *(home)* Extract historical charge chart card widget
- *(home)* Extract historical charge scroll view card widget
- *(home)* Add historical charge card widget
- *(home)* Add tooltip to historical charge card
## [0.4.0] - 2025-06-30

### 🚀 Features

- *(common)* Add responsive navigation to shell screen
- *(home)* Add pinned headers to historical charge scroll view

### 🐛 Bug Fixes

- *(settings)* Grid supply point group id form field spacing

### 💼 Other

- Add collection package

### 🚜 Refactor

- *(settings)* Add tariff form card widget
- *(welcome)* Add welcome card widget
- *(welcome)* Add card widgets to welcome screen
- *(common)* Extract shell bottom navigation bar widget
- *(common)* Add shell navigation rail widget
- *(settings)* Update about dialog children
- *(home)* Add crosses at to date time axis
- *(home)* Remove title from date time axis
- Convert date format strings to named constructors

### 🎨 Styling

- Add trailing comma to build method parameters
## [0.3.0] - 2025-06-18

### 🚀 Features

- Add point color mapper to chart series
- *(settings)* Add location icon button

### 🐛 Bug Fixes

- Remove header from chart trackball
- *(settings)* Grid supply point group id notifier
- *(settings)* Import product code notifier

### 💼 Other

- Add geolocator package
- Add access coarse location android permission
- Add url_launcher package
- Add view android intent
- Add ios application queries schemes

### 🚜 Refactor

- Add sort field value mapper to chart series
- Replace chart tooltip with trackball
- *(common)* Add remap num extension
- Add outline to theme color scheme
- Add surface container to theme color scheme
- *(welcome)* Add constant constructor to welcome route
- *(settings)* Rename welcome form to tariff form
- *(settings)* Add settings screen
- *(settings)* Add settings route
- *(common)* Add shell screen
- *(common)* Add shell route
- *(home)* Remove scaffold from home screen
- *(home)* Remove annotation from home route
- Rename grid supply point group ids
- Add grid supply point group name constants
- *(settings)* Add grid supply point group id form field
- *(settings)* Replace postcode form field
- Add address model
- Add place model
- Add user agent client
- Add to int bool extension method
- Add nominatim api client exception
- Add nominatim api client
- Add nominatim api client provider
- *(settings)* Replace padding with column spacing
- *(settings)* Update grid supply point group id form field spacing
- *(settings)* Add about button widget
- *(settings)* Replace padding with column spacing

### 🎨 Styling

- Alphabetize grid supply point group ids
## [0.2.0] - 2025-06-13

### 🚀 Features

- *(welcome)* Add error handling to continue button
- *(home)* Add refresh indicator
- *(home)* Add layout builder with chart and list view

### 💼 Other

- Add syncfusion_flutter_charts package

### 🚜 Refactor

- *(home)* Extract historical charge list view widget
- *(home)* Add historical charge chart widget

### ⚙️ Miscellaneous Tasks

- Add privacy policy
- Add terms of service
## [0.1.0] - 2025-06-06

### 🚀 Features

- *(home)* Add historical charge list view

### 🐛 Bug Fixes

- Uri query parameters data types
- *(home)* Historical charge list tile valid from time zone
- *(welcome)* List industry grid supply points nullability

### 💼 Other

- Add http package
- Add provider package
- Add intl package
- Add shared_preferences package
- Add go_router package
- Add go_router_builder package
- Add keystore properties and upload keystore
- Add missing imports to gradle file

### 🚜 Refactor

- Update application package
- Update application name
- Remove comments from main
- Update theme color scheme
- Update material app title
- Add historical charge model
- Add paginated historical charge list model
- Add octopus energy api client exception
- Add products service
- Add octopus energy api client
- Add octopus energy api client provider
- Add internet permission to android manifest
- *(home)* Extract historical charge list tile widget
- Format historical charge list tile title
- Format historical charge list tile subtitle
- Add app icon
- Update android app icon
- Update ios app icon
- Update macos app icon
- Update web app icon
- Update windows app icon
- Add shared preferences provider
- *(home)* Rename pages to screens
- *(home)* Add home route
- Add router to material app constructor
- *(welcome)* Add postcode form field
- *(welcome)* Add import product code form field
- Add grid supply point model
- Add paginated grid supply point list model
- Add industry service
- *(welcome)* Add continue button
- *(welcome)* Add welcome screen
- *(welcome)* Add welcome route
- Add router conditional redirect
- *(home)* Move home screen to feature folder
- *(home)* Move home route to feature folder
- *(home)* Move historical charge list tile to feature folder
- *(welcome)* Move continue button to feature folder
- *(welcome)* Move import product code form field to feature folder
- *(welcome)* Move postcode form field to feature folder
- *(welcome)* Move welcome form to feature folder
- *(welcome)* Move welcome screen to feature folder
- *(welcome)* Move welcome route to feature folder
- Add link model
- Add grid supply point group id constants
- Add payment method constants
- Add sample quotes model
- Add standard electricity tariff model
- Add eco 7 electricity tariff model
- Add gas tariff model
- Add sample consumption model
- Add product model
- Add retrieve a product method
- Nullablify model fields
- Rename region code preference
- Add import tariff code preference
- *(home)* Use product code and tariff code preferences

### ⚙️ Miscellaneous Tasks

- Initial commit
- Add release workflow
