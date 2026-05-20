package kicd.app.kicd;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class KicdApplication {

    public static void main(String[] args) {
        SpringApplication.run(KicdApplication.class, args);
        System.out.println("KICD Application started successfully.");
    }

}
