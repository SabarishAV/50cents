# 50cents

A new Flutter project.

## Project Structure
````
lib/
├── main.dart                  # entry point only
├── app.dart                   # root widget (MaterialApp, router, theme)
├── core/                      # shared by every feature
│   ├── config/                # env access
│   ├── network/               # dio client, error handling
│   ├── storage/               # secure token storage
│   ├── router/                # routes
│   ├── theme/                 # colors, ThemeData
│   ├── utils/                 # validators, helpers
│   └── widgets/               # reusable UI (text field, button)
└── features/
    └── auth/
        ├── data/              # API calls + models  (like Spring repository/DTOs)
        │   └── models/
        └── presentation/      # everything the user sees
            ├── pages/         # full screens
            ├── widgets/       # pieces used only by auth screens
            └── providers/     # state + logic (like hooks / a service)
````
