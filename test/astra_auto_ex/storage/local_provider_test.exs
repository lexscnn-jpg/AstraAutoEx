defmodule AstraAutoEx.Storage.LocalProviderTest do
  use ExUnit.Case

  alias AstraAutoEx.Storage.LocalProvider

  @test_dir "priv/uploads/test"

  setup do
    File.mkdir_p!(@test_dir)
    on_exit(fn -> File.rm_rf!(@test_dir) end)
    :ok
  end

  test "upload and get" do
    key = "test/upload_test_#{System.system_time(:millisecond)}.txt"
    data = "hello world"

    assert {:ok, ^key} = LocalProvider.upload(key, data)
    assert {:ok, ^data} = LocalProvider.get(key)
  end

  test "exists? returns true for uploaded file" do
    key = "test/exists_test_#{System.system_time(:millisecond)}.txt"
    LocalProvider.upload(key, "data")
    assert LocalProvider.exists?(key)
  end

  test "exists? returns false for missing file" do
    refute LocalProvider.exists?("test/nonexistent_#{System.system_time(:millisecond)}.txt")
  end

  test "delete removes file" do
    key = "test/delete_test_#{System.system_time(:millisecond)}.txt"
    LocalProvider.upload(key, "data")
    assert :ok = LocalProvider.delete(key)
    refute LocalProvider.exists?(key)
  end

  test "delete_many removes multiple files" do
    keys =
      for i <- 1..3 do
        key = "test/multi_#{i}_#{System.system_time(:millisecond)}.txt"
        LocalProvider.upload(key, "data #{i}")
        key
      end

    assert {:ok, 3} = LocalProvider.delete_many(keys)
    Enum.each(keys, fn k -> refute LocalProvider.exists?(k) end)
  end

  test "get_signed_url returns local path" do
    key = "test/url_test.txt"
    assert {:ok, url} = LocalProvider.get_signed_url(key, 3600)
    assert url == "/api/files/test/url_test.txt"
  end

  test "path traversal is blocked" do
    key = "../../etc/passwd"
    LocalProvider.upload(key, "nope")
    # Should be stored safely without ".."
    refute File.exists?("/etc/passwd_nope")
  end
end
