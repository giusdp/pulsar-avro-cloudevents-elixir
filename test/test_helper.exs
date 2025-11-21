Application.put_env(:avrora, :schemas_path, Path.expand("./test/fixtures/schemas/"))

# Load test support files
Code.require_file("support/fixtures.ex", __DIR__)

ExUnit.start()
