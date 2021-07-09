defmodule Mix.Tasks.SobelowToJunit do
  @moduledoc """
  Convert sobelow.sarif.json to Sobelow.xml
  """

  use Mix.Task

  @spec run(any) :: :ok | {:error, atom}
  def run(_) do
    json = generate_json()

    xml =
      json
      |> Enum.into([], fn x -> test_xml(x) end)
      |> wrap_xml
      |> String.replace(~r/ +/, " ")

    File.cwd!()
    |> Path.join("reports/sobelow.xml")
    |> File.write(xml)
  end

  defp load_json do
    File.cwd!()
    |> Path.join("reports/sobelow.sarif.json")
    |> File.read!()
    |> Jason.decode!()
  end

  defp generate_json do
    [%{"results" => results}] =
      load_json()
      |> Access.get("runs")

    [%{"tool" => %{"driver" => %{"rules" => rules}}}] =
      load_json()
      |> Access.get("runs")

    tests =
      rules
      |> Enum.into([], fn x -> format_test(x) end)

    results
    |> Enum.into([], fn x -> format_error(x, tests) end)
  end

  #
  # Recast the objects
  #
  def format_test(
        %{
          "fullDescription" => %{
            "text" => full_description
          },
          "help" => %{
            "text" => help_text
          },
          "id" => id,
          "name" => name,
          "shortDescription" => %{
            "text" => short_description
          }
        } = _test
      ) do
    %{
      "description" => full_description,
      "short_description" => short_description,
      "help_text" => help_text,
      "name" => name,
      "id" => id
    }
  end

  def format_error(
        %{
          "level" => failure_level,
          "locations" => [
            %{
              "physicalLocation" => %{
                "artifactLocation" => %{"uri" => file_uri},
                "region" => %{
                  "startColumn" => start_column,
                  "endColumn" => end_column,
                  "startLine" => start_line,
                  "endLine" => end_line
                }
              }
            }
          ],
          "message" => %{"text" => message},
          "partialFingerprints" => %{
            "primaryLocationLineHash" => line_hash
          },
          "ruleId" => id
        } = _error,
        tests
      ) do
    %{
      "rule_id" => id,
      "test" => Enum.filter(tests, fn %{"id" => rule_id} -> match?(^id, rule_id) end),
      "failure_level" => failure_level,
      "message" => message,
      "line_hash" => line_hash,
      "file" => %{
        "uri" => file_uri,
        "column" => %{
          "start" => start_column,
          "end" => end_column
        },
        "line" => %{
          "start" => start_line,
          "end" => end_line
        }
      }
    }
  end

  #
  # XML Generation
  #
  defp wrap_xml(xml) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuite>
      #{xml}
    </testsuite>
    """
  end

  defp filename(filename, start_line, ""), do: "#{filename}:#{start_line}"

  defp filename(filename, start_line, start_column),
    do: "#{filename}:#{start_line}:#{start_column}"

  @radius 5

  defp get_snippet(file, line) do
    if File.regular?(file) and is_integer(line) do
      to_discard = max(line - @radius - 1, 0)
      lines = File.stream!(file) |> Stream.take(line + 5) |> Stream.drop(to_discard)

      {first_five, lines} = Enum.split(lines, line - to_discard - 1)
      first_five = with_line_number(first_five, to_discard + 1, false)

      {center, last_five} = Enum.split(lines, 1)
      center = with_line_number(center, line, true)
      last_five = with_line_number(last_five, line + 1, false)

      first_five ++ center ++ last_five
    end
  end

  defp with_line_number(lines, initial, highlight) do
    lines
    |> Enum.map_reduce(initial, fn line, acc -> {{"File (#{acc})> ", line}, acc + 1} end)
    |> elem(0)
  end

  def test_xml(%{
        "failure_level" => failure_level,
        "file" => %{
          "column" => %{
            "end" => _end_column,
            "start" => start_column
          },
          "line" => %{
            "end" => _end_line,
            "start" => start_line
          },
          "uri" => file_uri
        },
        "line_hash" => _line_hash,
        "message" => _message,
        "rule_id" => _id,
        "test" => [
          %{
            "description" => full_description,
            "help_text" => help_text,
            "id" => _test_id,
            "name" => name,
            "short_description" => short_description
          }
        ]
      }) do
    code_snippet =
      file_uri
      |> get_snippet(start_line)
      |> Enum.flat_map(fn {x, y} -> [x <> y] end)
      |> List.foldl("", fn x, acc -> acc <> x end)

    """
    <testcase name="#{name}"
              file="#{filename(file_uri, start_line, start_column)}"
              assertions="#{
      short_description |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    }">
      <failure type="#{failure_level}">
        #{help_text}
        #{filename(file_uri, start_line, start_column)} (#{name} #{full_description})

        #{code_snippet}
      </failure>
    </testcase>
    """
  end
end
