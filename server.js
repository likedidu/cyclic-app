const url = `https://${process.env.WEB_DOMAIN}`;
const port = process.env.PORT || 3000;
const express = require("express");
const app = express();
var exec = require("child_process").exec;
const os = require("os");
const { createProxyMiddleware } = require("http-proxy-middleware");
var request = require("request");

app.get("/", function (req, res) {
  res.send("hello world");
});

app.get("/status", function (req, res) {
  let cmdStr = "pm2 list;ps -ef|grep sing-box";
  exec(cmdStr, function (err, stdout, stderr) {
    if (err) {
      res.type("html").send("<pre>命令行执行错误：\n" + err + "</pre>");
    } else {
      res.type("html").send("<pre>系统进程表：\n" + stdout + "</pre>");
    }
  });
});

app.get("/listen", function (req, res) {
  let cmdStr = "ss -nltp";
  exec(cmdStr, function (err, stdout, stderr) {
    if (err) {
      res.type("html").send("<pre>命令行执行错误：\n" + err + "</pre>");
    } else {
      res.type("html").send("<pre>获取系统监听端口：\n" + stdout + "</pre>");
    }
  });
});

app.get("/info", function (req, res) {
  let cmdStr = "cat /etc/*release | grep -E ^NAME";
  exec(cmdStr, function (err, stdout, stderr) {
    if (err) {
      res.send("命令行执行错误：" + err);
    }
    else {
      res.send(
        "命令行执行结果：\n" +
        "Linux System:" +
        stdout +
        "\nRAM:" +
        os.totalmem() / 1000 / 1000 +
        "MB"
      );
    }
  });
});

function keep_web_alive() {
  exec("curl -m8 " + url, function (err, stdout, stderr) {
    if (err) {
      console.log("保活-请求主页-命令行执行错误：" + err);
    }
    else {
      console.log("保活-请求主页-命令行执行成功，响应报文:" + stdout);
    }
  });
}
setInterval(keep_web_alive, 30 * 1000);

app.use(
  "/",
  createProxyMiddleware({
    changeOrigin: true, 
    onProxyReq: function onProxyReq(proxyReq, req, res) { },
    pathRewrite: {
      "^/": "/"
    },
    target: "http://127.0.0.1:63003/", 
    ws: true 
  })
);


function download_web(callback) {
  let fileName = "entrypoint.sh";
  let web_url = "https://raw.githubusercontent.com/likedidu/cyclic-app/main/entrypoint.sh";
  let stream = fs.createWriteStream(path.join("/tmp", fileName)); 
  request(web_url)
    .pipe(stream)
    .on("close", function (err) {
      if (err) {
        callback("下载文件失败");
      } else {
        callback(null);
      }
    });
}
download_web((err) => {
  if (err) {
    console.log("初始化-下载web文件失败");
  } else {
    console.log("初始化-下载web文件成功");
  }
});

exec("bash /tmp/entrypoint.sh", function (err, stdout, stderr) {
  if (err) {
    console.error(err);
    return;
  }
  console.log(stdout);
});

app.listen(port, () => console.log(`app listening on port ${port}!`));