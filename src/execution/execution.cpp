#include "symphony/execution/execution.hpp"

#include <condition_variable>
#include <exception>
#include <map>
#include <limits>
#include <mutex>
#include <stdexcept>
#include <utility>

#include <exec/start_detached.hpp>
#include <exec/static_thread_pool.hpp>
#include <stdexec/execution.hpp>

namespace symphony::execution {
namespace {
std::size_t validated_worker_count(const std::size_t worker_count) {
  if (worker_count == 0) {
    throw std::invalid_argument("worker_count must be positive");
  }
  return worker_count;
}

WorkerOutcome invoke(WorkerTask& task, const std::stop_token stop_token) noexcept {
  try {
    return task(stop_token);
  } catch (const std::exception& error) {
    WorkerOutcome outcome;
    outcome.result.error = error.what();
    return outcome;
  } catch (...) {
    WorkerOutcome outcome;
    outcome.result.error = "worker task failed with non-standard exception";
    return outcome;
  }
}
}  // namespace

void InlineWorkerExecutor::submit(std::string key, WorkerTask task) {
  ready_.push_back(
      WorkerCompletion{std::move(key), invoke(task, std::stop_token{})});
}

bool InlineWorkerExecutor::request_stop(std::string_view) { return false; }

std::vector<WorkerCompletion> InlineWorkerExecutor::take_ready() {
  return std::exchange(ready_, std::vector<WorkerCompletion>{});
}

std::size_t InlineWorkerExecutor::capacity() const noexcept {
  return std::numeric_limits<std::size_t>::max();
}

void InlineWorkerExecutor::wait() {}

struct StdexecWorkerExecutor::Impl {
  explicit Impl(const std::size_t count) : tasks(count) {}

  void complete(std::string key, WorkerOutcome outcome) {
    const std::scoped_lock lock(mutex);
    ready.push_back(WorkerCompletion{std::move(key), std::move(outcome)});
  }

  std::mutex mutex;
  std::vector<WorkerCompletion> ready;
  StdexecTaskExecutor tasks;
};

struct StdexecTaskExecutor::Impl {
  explicit Impl(const std::size_t count)
      : worker_count(validated_worker_count(count)), pool(worker_count) {}

  void finish(const std::string_view key) {
    {
      const std::scoped_lock lock(mutex);
      stop_sources.erase(key);
    }
    idle.notify_all();
  }

  std::mutex mutex;
  std::condition_variable idle;
  std::map<std::string, std::stop_source, std::less<>> stop_sources;
  std::size_t worker_count;
  exec::static_thread_pool pool;
};

StdexecTaskExecutor::StdexecTaskExecutor(const std::size_t worker_count)
    : impl_(std::make_unique<Impl>(worker_count)) {}

StdexecTaskExecutor::~StdexecTaskExecutor() {
  if (impl_) wait();
}

void StdexecTaskExecutor::submit(std::string key, ExecutionTask task) {
  const auto registered_key = key;
  std::stop_token stop_token;
  {
    const std::scoped_lock lock(impl_->mutex);
    auto [position, inserted] =
        impl_->stop_sources.emplace(key, std::stop_source{});
    if (!inserted) {
      throw std::invalid_argument("execution key is already active");
    }
    stop_token = position->second.get_token();
  }

  try {
    auto sender = stdexec::starts_on(
        impl_->pool.get_scheduler(),
        stdexec::just() |
            stdexec::then([impl = impl_.get(), key = std::move(key),
                           task = std::move(task),
                           stop_token]() mutable noexcept {
              task(stop_token);
              impl->finish(key);
            }));
    exec::start_detached(std::move(sender));
  } catch (...) {
    impl_->finish(registered_key);
    throw;
  }
}

bool StdexecTaskExecutor::request_stop(const std::string_view key) {
  const std::scoped_lock lock(impl_->mutex);
  const auto found = impl_->stop_sources.find(key);
  if (found == impl_->stop_sources.end()) return false;
  static_cast<void>(found->second.request_stop());
  return true;
}

std::size_t StdexecTaskExecutor::capacity() const noexcept {
  return impl_->worker_count;
}

void StdexecTaskExecutor::drain() {
  std::unique_lock lock(impl_->mutex);
  impl_->idle.wait(lock, [this] { return impl_->stop_sources.empty(); });
}

void StdexecTaskExecutor::wait() {
  std::unique_lock lock(impl_->mutex);
  for (auto& [key, source] : impl_->stop_sources) {
    static_cast<void>(key);
    static_cast<void>(source.request_stop());
  }
  impl_->idle.wait(lock, [this] { return impl_->stop_sources.empty(); });
}

StdexecWorkerExecutor::StdexecWorkerExecutor(const std::size_t worker_count)
    : impl_(std::make_unique<Impl>(validated_worker_count(worker_count))) {}

StdexecWorkerExecutor::~StdexecWorkerExecutor() {
  if (impl_) wait();
}

void StdexecWorkerExecutor::submit(std::string key, WorkerTask task) {
  const auto task_key = key;
  impl_->tasks.submit(
      task_key,
      [impl = impl_.get(), key = std::move(key), task = std::move(task)](
          const std::stop_token stop_token) mutable noexcept {
        impl->complete(std::move(key), invoke(task, stop_token));
      });
}

bool StdexecWorkerExecutor::request_stop(const std::string_view key) {
  return impl_->tasks.request_stop(key);
}

std::vector<WorkerCompletion> StdexecWorkerExecutor::take_ready() {
  const std::scoped_lock lock(impl_->mutex);
  return std::exchange(impl_->ready, std::vector<WorkerCompletion>{});
}

std::size_t StdexecWorkerExecutor::capacity() const noexcept {
  return impl_->tasks.capacity();
}

void StdexecWorkerExecutor::wait() { impl_->tasks.wait(); }

}  // namespace symphony::execution
