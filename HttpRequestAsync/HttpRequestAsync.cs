using Microsoft.SqlServer.Server;
using System.Threading;

public class HttpRequestAsync {

    [SqlProcedure]
    public static void SendAsync(string uri, string method, int? timeoutMs, string contentType, string headersXml, byte[] body) {
        var thread = new Thread(new ThreadStart(() => {
            HttpRequest.Send(uri, method, timeoutMs, contentType, headersXml, body);
        }));

        thread.IsBackground = true;
        thread.Start();
    }


}

