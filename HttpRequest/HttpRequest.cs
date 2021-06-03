using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using Microsoft.SqlServer.Server;
using System.Data.SqlTypes;
using System.Collections;
using System.Net;
using System.IO;
using System.Xml;

public class HttpRequest {

    [SqlFunction(FillRowMethodName = "FillHttpResponse")]
    public static IEnumerable Send(string uri, string method, int? timeoutMs, string contentType, string headersXml, byte[] body) {
        var requestUri = new Uri(uri);

        var request = (HttpWebRequest)WebRequest.Create(requestUri);

        request.Credentials = CredentialCache.DefaultCredentials;
        request.Method = method.ToUpper().Trim();

        request.Timeout = timeoutMs == null ? 3000 : timeoutMs.Value;

        if (headersXml != null) {

            var headersDs = new DataSet();

            var headerXmlStringReader = new StringReader(headersXml);
            headersDs.ReadXml(headerXmlStringReader, XmlReadMode.InferSchema);
            headerXmlStringReader.Close();

            var requestHeaders = new WebHeaderCollection();

            foreach (DataRow row in headersDs.Tables[0].Rows) {
                requestHeaders.Add((string)row[0], (string)row[1]);
            }

            request.Headers = requestHeaders;
        }

        if (contentType != null) {

            request.ContentType = contentType;
        }

        if (body != null) {

            request.ContentLength = body.Length;

            var stream = request.GetRequestStream();
            stream.Write(body, 0, body.Length);
            stream.Close();
        }

        var response = (HttpWebResponse)request.GetResponse();

        var responseContentLength = response.ContentLength;
        var responseContentType = response.ContentType;

        var responseStream = response.GetResponseStream();

        var responseBodyStream = new MemoryStream();
        responseStream.CopyTo(responseBodyStream);
        responseStream.Close();

        var responseBody = responseBodyStream.ToArray();
        responseBodyStream.Close();

        responseStream.Close();

        var responseStatus = Convert.ToInt32(response.StatusCode);

        IList<(int, string, long, string, byte[])> responseHeaders = new List<(int, string, long, string, byte[])>();

        var responseHeadersDt = new DataTable("headers");
        responseHeadersDt.Columns.Add("name", typeof(string));
        responseHeadersDt.Columns.Add("value", typeof(string));

        for (int i = 0; i < response.Headers.Count; i++) {
            responseHeadersDt.Rows.Add(new object[] { response.Headers.GetKey(i), response.Headers.Get(i) });
        }

        string responseHeadersXml;

        using (var stringWriter = new StringWriter()) {
            responseHeadersDt.WriteXml(stringWriter, XmlWriteMode.IgnoreSchema);
            responseHeadersXml = stringWriter.ToString();
        }

        responseHeaders.Add((responseStatus, responseContentType, responseContentLength, responseHeadersXml, responseBody));

        return responseHeaders;
    }

    public static void FillHttpResponse(object obj, out SqlInt32 status, out SqlString contentType, out SqlInt64 contentLength, out SqlXml headers, out SqlBinary body) {
        var responseData = ((int, string, long, string, byte[]))obj;

        status = responseData.Item1;
        contentType = responseData.Item2;
        contentLength = responseData.Item3;
        body = responseData.Item5;

        MemoryStream memoryStream = new MemoryStream(new UTF8Encoding().GetBytes(responseData.Item4));
        var value = new SqlXml(XmlReader.Create(memoryStream));
        headers = value;

        memoryStream.Close();
    }


}