Application.put_env(:avrora, :schemas_path, Path.expand("./test/fixtures/schemas/"))
ExUnit.start()
