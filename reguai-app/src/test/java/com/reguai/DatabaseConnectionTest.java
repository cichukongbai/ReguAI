//package com.reguai;
//
//import javax.sql.DataSource;
//
//import org.junit.jupiter.api.Test;
//import org.springframework.beans.factory.annotation.Autowired;
//import org.springframework.boot.test.context.SpringBootTest;
//
//import java.sql.Connection;
//
//import static org.junit.jupiter.api.Assertions.assertTrue;
//@SpringBootTest
//public class DatabaseConnectionTest {
//        @Autowired
//        private DataSource dataSource;
//
//        @Test
//        void shouldConnectToPostgreSQL() throws Exception {
//            try (Connection connection = dataSource.getConnection()) {
//                assertTrue(connection.isValid(3));
//                System.out.println(
//                        "Database connected: "
//                                + connection.getMetaData().getURL()
//                );
//            }
//        }
//
//}
