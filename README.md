## Demo Project to implement Hangman game (v2)

### Dictionary and Hangman components are implemented as self-contained elixir services (applications) and implemented one browser client to expose the Hangman game to end users. Added user authentication (phx.gen.auth) and there exists only one Hangman GenServer process per user (used Registry to uniquely name the server process). 

### The language and technologies used:
- Elixir 1.8.4/OTP 27
- Phoenix 1.7.21/LiveView
- Html/JavaScript/TailwindCSS

### How to run locally
- Clone the repo
- cd hangman2
- mix setup
- mix phx.server
