package com.salesforce.research.poc;


import org.glassfish.grizzly.http.server.HttpServer;
import org.glassfish.grizzly.http.server.NetworkListener;
import org.glassfish.grizzly.http.server.StaticHttpHandler;
import org.glassfish.grizzly.servlet.WebappContext;
import org.glassfish.jersey.servlet.ServletContainer;

import javax.servlet.ServletRegistration;
import java.io.IOException;


public class Server {

    public static void main(String[] args) throws IOException {
        final HttpServer server = new HttpServer();
        final NetworkListener listener = new NetworkListener("grizzly-listener", "localhost", 8888);
        server.addListener(listener);

        final StaticHttpHandler staticHttpHandler = new StaticHttpHandler("static");
        staticHttpHandler.setFileCacheEnabled(false);
        server.getServerConfiguration().addHttpHandler(staticHttpHandler, "/static/");

        server.start();

        final WebappContext context = new WebappContext("Kol Zchut Server");
        final ServletRegistration servletRegistration = context
                .addServlet("ServletContainer", ServletContainer.class);
        servletRegistration.addMapping("/rest/*");
        servletRegistration.setInitParameter("javax.ws.rs.Application"
                , "com.salesforce.research.poc.MyApplication");

        context.deploy(server);


        System.in.read();

        server.shutdownNow();

    }
}
