import python

module SourcesAndSinks{
    private import semmle.python.dataflow.new.DataFlow
    private import semmle.python.dataflow.new.TaintTracking
    private import semmle.python.Concepts
    private import semmle.python.dataflow.new.BarrierGuards
    private import semmle.python.ApiGraphs
    private import DataFlow::PathGraph
    private import semmle.python.frameworks.Flask


    // ========== Sources ==========
    abstract class LocalSources extends DataFlow::Node { }

    // Standard Input from user
    class STDInputSources extends LocalSources {
    STDInputSources() {
        exists(DataFlow::Node call |
        (
            // v = input("Input?")
            call = API::builtin("input").getACall()
            or
            // https://docs.python.org/3/library/fileinput.html
            call = API::moduleImport("fileinput").getMember("input").getACall()
        ) and
        this = call
        )
    }
    }

    // Command Line Arguments
    class CommandLineArgumentsSources extends LocalSources {
    CommandLineArgumentsSources() {
        exists(DataFlow::Node call |
        (
            // v = sys.args[1]
            call = API::moduleImport("sys").getMember("argv").getAUse()
            or
            // parser = argparse.ArgumentParser(__name__)
            // ...
            // arguments = parser.parse_args()
            // v = arguments.t     # user input
            // TODO: This doesn't work but needs supported
            call = API::moduleImport("argparse").getMember("ArgumentParser").getAUse()
        ) and
        this = call
        )
    }
    }

    // Local Enviroment Variables
    class EnviromentVariablesSources extends LocalSources {
    EnviromentVariablesSources() {
        exists(DataFlow::Node call |
        (
            // os.getenv('abc')
            call = API::moduleImport("os").getMember("getenv").getACall()
            or
            // os.environ['abc']
            // os.environ.get('abc')
            call = API::moduleImport("os").getMember("environ").getAUse()
        ) and
        this = call
        )
    }
    }

    // Local File Reads
    class FileReadSource extends LocalSources {
    FileReadSource() {
        exists(DataFlow::Node call |
        (
            // https://docs.python.org/3/library/functions.html#open
            // var = open('abc.txt')
            call = API::builtin("open").getACall()
            or
            // https://docs.python.org/3/library/os.html#os.open
            call = API::moduleImport("os").getMember("open").getACall()
        ) and
        this = call
        )
    }
    }

    abstract class LoggingSinks extends DataFlow::Node { }

class PrintMethod extends LoggingSinks {
  PrintMethod() {
    exists(DataFlow::Node call |
      call = API::builtin("print").getACall() and
      this = call
    )
  }
}

class LoggingFramework extends LoggingSinks {
  LoggingFramework() {
    exists(DataFlow::Node call, API::Node node |
      (
        node = API::moduleImport("logging") and
        (
          call = node.getMember("info").getACall()
          or
          call = node.getMember("debug").getACall()
          or
          call = node.getMember("warning").getACall()
          or
          call = node.getMember("error").getACall()
        )
      ) and
      this = call
    )
  }
 }

 abstract class CredentialSink extends DataFlow::Node { }

Expr getDictValueByKey(Dict dict, string key) {
  exists(KeyValuePair item |
    // d = {KEY: VALUE}
    item = dict.getAnItem() and
    key = item.getKey().(StrConst).getS() and
    result = item.getValue()
  )
}

Expr getAssignStmtByKey(AssignStmt assign, string key) {
  exists(Subscript sub |
    // dict['KEY'] = VALUE
    sub = assign.getASubExpression() and
    // Make sure the keys match
    // TODO: What happens if this value itself is not static?
    key = sub.getASubExpression().(StrConst).getS() and
    // TODO: Only supports static strings, resolve the value??
    // result = assign.getASubExpression().(StrConst)
    result = sub.getValue()
  )
}

Expr getAnyAssignStmtByKey(string key) { result = getAssignStmtByKey(any(AssignStmt a), key) }

// =========================
// Web Frameworks
// =========================
class FlaskCredentialSink extends CredentialSink {
  FlaskCredentialSink() {
    exists(API::Node node |
      exists(AssignStmt stmt |
        // app = flask.Flask(__name__)
        // app.secret_key = VALUE
        node = Flask::FlaskApp::instance().getMember("secret_key") and
        stmt = node.getAUse().asExpr().getParentNode() and
        this = DataFlow::exprNode(stmt.getValue())
      )
      or
      exists(Expr assign, AssignStmt stmt |
        // app.config['SECRET_KEY'] = VALUE
        assign = getAnyAssignStmtByKey("SECRET_KEY").getParentNode() and
        stmt = assign.getParentNode() and
        this = DataFlow::exprNode(stmt.getValue())
      )
      or
      // app.config.update(SECRET_KEY=VALUE)
      node = Flask::FlaskApp::instance().getMember("config").getMember("update") and
      this = DataFlow::exprNode(node.getACall().getArgByName("SECRET_KEY").asExpr())
    )
  }
}

// TODO: Django support
// =========================
// Databases
// =========================
class MySqlSink extends CredentialSink {
  MySqlSink() {
    this =
      API::moduleImport("mysql.connector").getMember("connect").getACall().getArgByName("password")
  }
}

class AsyncpgSink extends CredentialSink {
  AsyncpgSink() {
    this = API::moduleImport("asyncpg").getMember("connect").getACall().getArgByName("password")
  }
}

class PsycopgSink extends CredentialSink {
  PsycopgSink() {
    this = API::moduleImport("psycopg2").getMember("connect").getACall().getArgByName("password")
  }
}

class AioredisSink extends CredentialSink {
  AioredisSink() {
    this =
      API::moduleImport("aioredis")
          .getMember("create_connection")
          .getACall()
          .getArgByName("password")
    or
    this =
      API::moduleImport("aioredis").getMember("create_pool").getACall().getArgByName("password")
    or
    this =
      API::moduleImport("aioredis").getMember("create_redis").getACall().getArgByName("password")
    or
    // redis = await aioredis.create_redis_pool(
    //   'redis://localhost', password='sEcRet')
    this =
      API::moduleImport("aioredis")
          .getMember("create_redis_pool")
          .getACall()
          .getArgByName("password")
    or
    this =
      API::moduleImport("aioredis.sentinel")
          .getMember("create_sentinel")
          .getACall()
          .getArgByName("password")
    or
    this =
      API::moduleImport("aioredis.sentinel")
          .getMember("create_sentinel_pool")
          .getACall()
          .getArgByName("password")
  }
}

// =========================
// Utils
// =========================
class RequestsSink extends CredentialSink {
  RequestsSink() {
    // from requests.auth import HTTPBasicAuth
    // auth = HTTPBasicAuth('user', 'mysecretpassword')
    this = API::moduleImport("requests.auth").getMember("HTTPBasicAuth").getACall().getArg(1)
  }
}

class PyJwtSink extends CredentialSink {
  PyJwtSink() {
    // import jwt
    // encoded = jwt.encode({"some": "payload"}, "secret", algorithm="HS256")
    this = API::moduleImport("jwt").getMember("encode").getACall().getArg(1)
    or
    // decode = jwt.decode(encoded, "secret", algorithm="HS256")
    this = API::moduleImport("jwt").getMember("decode").getACall().getArg(1)
  }
}

class PyOtpSink extends CredentialSink {
  PyOtpSink() {
    // import pyotp
    // totp = pyotp.TOTP('base32secret3232')
    this = API::moduleImport("pyotp").getMember("TOTP").getACall().getArg(1)
  }
}

class Boto3Sink extends CredentialSink {
  Boto3Sink() {
    // https://docs.min.io/docs/how-to-use-aws-sdk-for-python-with-minio-server.html
    exists(DataFlow::CallCfgNode calls |
      // s3 = boto3.resource('s3',
      //     aws_access_key_id='YOUR-ACCESSKEYID',
      //     aws_secret_access_key='YOUR-SECRETACCESSKEY'
      //     aws_session_token="YOUR-SESSION-TOKEN"
      // )
      calls = API::moduleImport("boto3").getMember(["client", "resource"]).getACall() and
      (
        this = calls.getArgByName("aws_access_key_id") or
        this = calls.getArgByName("aws_secret_access_key") or
        this = calls.getArgByName("aws_session_token")
      )
    )
  }
}
} 
