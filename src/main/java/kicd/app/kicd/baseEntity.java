package kicd.app.kicd;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

public class baseEntity {

    @Getter
    @Setter
    @MappedSuperclass
    public abstract class BaseEntity {

        @Id
        @GeneratedValue(strategy = GenerationType.IDENTITY)
        private Long id;

        private LocalDateTime createdAt;

        private LocalDateTime updatedAt;

        @PrePersist
        public void onCreate() {
            createdAt = LocalDateTime.now();
        }

        @PreUpdate
        public void onUpdate() {
            updatedAt = LocalDateTime.now();
        }
    }
}
