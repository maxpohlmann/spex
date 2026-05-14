File.rm_rf!("./spex_dets")

ExUnit.after_suite(fn _ ->
  File.rm_rf!("./spex_dets")
end)

Spex.Testing.prepare_for_test_suite()

ExUnit.start()
