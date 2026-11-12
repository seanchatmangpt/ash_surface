ExUnit.start()
ExUnit.after_suite(fn _ -> AshSurface.TestTmp.sweep() end)
