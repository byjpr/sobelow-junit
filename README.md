# SobelowJunit

Convert sobelow.sarif.json files into JUnit XML. This tool was primarily made to produce JUnit consumable tests reports for CircleCI.

## Usage

1. Add sobelow_junit to your mix.exs `{:sobelow_junit, git: "https://github.com/byjpr/sobelow-junit", only: [:dev, :test], runtime: false}`
2. Run Sobelow and save output to reports/sobelow.sarif.json `$ mix sobelow $1 --format sarif >> reports/sobelow.sarif.json`
3. Convert sobelow.sarif.json to reports/sobelow.xml `mix sobelow_to_junit`

## Installation

```elixir
def deps do
  [
    {:sobelow_junit, git: "https://github.com/byjpr/sobelow-junit", only: [:dev, :test], runtime: false}
  ]
end
```
