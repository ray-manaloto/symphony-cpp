#include <ut/ut.hpp>

#include <string_view>
#include <tuple>

#include <boost/sqlite/connection.hpp>
#include <boost/sqlite/error.hpp>
#include <boost/sqlite/query.hpp>
#include <boost/sqlite/transaction.hpp>
#include <boost/system/error_code.hpp>

namespace sqlite = boost::sqlite;

namespace {

sqlite3_int64 row_count(sqlite::connection_ref connection) {
  for (const auto& [count] :
       sqlite::query<std::tuple<sqlite3_int64>>(connection, "SELECT count(*) FROM events")) {
    return count;
  }
  return -1;
}

} // namespace

static ut::suite persistence_provider_tests = [] {
  ut::test("boost sqlite provides transactional typed fixture access") = [] {
    sqlite::connection connection{sqlite::in_memory};
    connection.execute("PRAGMA journal_mode = WAL;"
                       "CREATE TABLE events("
                       "  id INTEGER PRIMARY KEY,"
                       "  payload TEXT NOT NULL"
                       ");");

    {
      sqlite::transaction transaction{connection};
      connection.prepare("INSERT INTO events(payload) VALUES (?1)").execute({"rolled back"});
    }
    ut::expect(row_count(connection) == 0);

    {
      sqlite::transaction transaction{connection};
      connection.prepare("INSERT INTO events(payload) VALUES (?1)").execute({"committed"});
      transaction.commit();
    }
    ut::expect(row_count(connection) == 1);

    boost::system::error_code error;
    sqlite::error_info detail;
    connection.execute("SELECT * FROM missing_fixture_table", error, detail);
    ut::expect(static_cast<bool>(error));
    ut::expect(std::string_view{detail.message()}.contains("missing_fixture_table"));
  };
};
