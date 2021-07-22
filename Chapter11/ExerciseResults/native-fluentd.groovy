class Main {
  public static void main (String[] args)
  {
    // all args are joined to create the JSON payload
    // remember to escape the quotes e.g   {\"a\":\"b\"}
    // the address is hardwired here
    String URLStr = "http://localhost:18085/test";

    String output = args.join(" ");
    System.out.println ("Sending >"+ output + "< to >" + URLStr + "<")


    URL fluentdURL = new URL(URLStr);
    URLConnection webConnection = fluentdURL.openConnection();
    webConnection.doOutput = true;
    webConnection.requestMethod = 'POST';
    webConnection.setRequestProperty("content-type", "application/json");



    boolean sent = false;

    while (!sent)
    {
      try{                        
        webConnection.with {
              outputStream.withWriter { writer ->  writer << output }
              outputStream.flush();
        }
        String response= webConnection.getContent();
        sent = true;

      }
      catch (Exception err)
      {
        System.out.println ("Err, trying again in a moment \n"+err.toString());
        sleep (60);

      }
    }
  }       
}            