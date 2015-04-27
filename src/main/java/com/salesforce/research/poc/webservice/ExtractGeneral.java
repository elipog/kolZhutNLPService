package com.salesforce.research.poc.webservice;

import Algorithms.Categorization;
import Model.Category;

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import java.io.IOException;
import java.util.List;


@Path("/categorize")
public class ExtractGeneral {

    @GET
    @Consumes(MediaType.TEXT_PLAIN)
    @Produces({MediaType.APPLICATION_JSON+ ";charset=utf-8"})
    @HeaderParam("CacheControl :no-cache")
    public List<Category> parseText(@QueryParam("query")String query) throws IOException {
        if(query == null) return null;
        System.out.println(query);
        Categorization c = Categorization.getInstance();
        List<Category> categories = c.getCategories(query);
        System.out.println(categories!=null);
        return categories;
    }


}
