#pragma once

#include <chrono>
#include <cstddef>
#include <functional>
#include <memory>
#include <optional>
#include <stop_token>
#include <string>
#include <string_view>
#include <vector>

#include "symphony/codex/codex.hpp"
#include "symphony/domain/domain.hpp"

namespace symphony::execution {

struct WorkerOutcome {
  codex::RunResult result;
  std::optional<domain::Issue> refreshed_issue;
  std::optional<std::string> after_run_hook;
  std::chrono::milliseconds hook_timeout{0};
};

struct WorkerCompletion {
  std::string key;
  WorkerOutcome outcome;
};

using WorkerTask = std::function<WorkerOutcome(std::stop_token)>;

using ExecutionTask = std::move_only_function<void(std::stop_token) noexcept>;

class StdexecTaskExecutor final {
 public:
  explicit StdexecTaskExecutor(std::size_t worker_count);
  ~StdexecTaskExecutor();

  StdexecTaskExecutor(const StdexecTaskExecutor&) = delete;
  StdexecTaskExecutor& operator=(const StdexecTaskExecutor&) = delete;
  StdexecTaskExecutor(StdexecTaskExecutor&&) = delete;
  StdexecTaskExecutor& operator=(StdexecTaskExecutor&&) = delete;

  void submit(std::string key, ExecutionTask task);
  [[nodiscard]] bool request_stop(std::string_view key);
  [[nodiscard]] std::size_t capacity() const noexcept;
  void wait();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

class WorkerExecutor {
 public:
  virtual ~WorkerExecutor() = default;
  virtual void submit(std::string key, WorkerTask task) = 0;
  [[nodiscard]] virtual bool request_stop(std::string_view key) = 0;
  [[nodiscard]] virtual std::vector<WorkerCompletion> take_ready() = 0;
  [[nodiscard]] virtual std::size_t capacity() const noexcept = 0;
  virtual void wait() = 0;
};

class InlineWorkerExecutor final : public WorkerExecutor {
 public:
  void submit(std::string key, WorkerTask task) override;
  [[nodiscard]] bool request_stop(std::string_view key) override;
  [[nodiscard]] std::vector<WorkerCompletion> take_ready() override;
  [[nodiscard]] std::size_t capacity() const noexcept override;
  void wait() override;

 private:
  std::vector<WorkerCompletion> ready_;
};

class StdexecWorkerExecutor final : public WorkerExecutor {
 public:
  explicit StdexecWorkerExecutor(std::size_t worker_count);
  ~StdexecWorkerExecutor() override;

  StdexecWorkerExecutor(const StdexecWorkerExecutor&) = delete;
  StdexecWorkerExecutor& operator=(const StdexecWorkerExecutor&) = delete;
  StdexecWorkerExecutor(StdexecWorkerExecutor&&) = delete;
  StdexecWorkerExecutor& operator=(StdexecWorkerExecutor&&) = delete;

  void submit(std::string key, WorkerTask task) override;
  [[nodiscard]] bool request_stop(std::string_view key) override;
  [[nodiscard]] std::vector<WorkerCompletion> take_ready() override;
  [[nodiscard]] std::size_t capacity() const noexcept override;
  void wait() override;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace symphony::execution
#include <chrono>
