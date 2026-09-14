import ursina
from ursina.prefabs.first_person_controller import FirstPersonController
from bullet import Bullet
from enemy import get_player_color, create_player_texture


MAX_HEALTH = 250


class Player(FirstPersonController):
    def __init__(self, position: ursina.Vec3, network):
        super().__init__(
            position=position,
            model="cube",
            jump_height=2.5,
            jump_duration=0.4,
            origin_y=-2,
            collider="box",
            speed=7
        )
        self.cursor.color = ursina.color.rgba(255, 0, 0, 122)

        my_id = getattr(network, 'id', '1') if network else '1'
        my_username = getattr(network, 'username', '') if network else ''
        self.color_rgb = get_player_color(my_id, my_username)
        self.gun_color = ursina.color.rgb32(self.color_rgb[0], self.color_rgb[1], self.color_rgb[2])

        self.color = self.gun_color
        self.texture = create_player_texture(self.color_rgb)

        self.gun = ursina.Entity(
            parent=ursina.camera.ui,
            position=ursina.Vec2(0.6, -0.45),
            scale=ursina.Vec3(0.1, 0.2, 0.65),
            rotation=ursina.Vec3(-20, -20, -5),
            model="cube",
            texture="white_cube",
            color=self.gun_color
        )

        self.healthbar_pos = ursina.Vec2(0, 0.45)
        self.healthbar_size = ursina.Vec2(0.8, 0.04)
        self.healthbar_bg = ursina.Entity(
            parent=ursina.camera.ui,
            model="quad",
            color=ursina.color.rgb(255, 0, 0),
            position=ursina.Vec3(0, 0.45, 0),
            scale=self.healthbar_size
        )
        self.healthbar = ursina.Entity(
            parent=ursina.camera.ui,
            model="quad",
            color=ursina.color.rgb(0, 255, 0),
            position=ursina.Vec3(0, 0.45, -0.01),
            scale=self.healthbar_size
        )
        self.max_health = MAX_HEALTH
        self.health = self.max_health

        self.health_text = ursina.Text(
            parent=ursina.camera.ui,
            text=f"{int(self.health)} / {self.max_health} HP",
            position=ursina.Vec2(0, 0.41),
            origin=ursina.Vec2(0, 0),
            scale=1.0,
            color=ursina.color.white
        )

        self.network = network
        self.gun_sound = ursina.Audio('assets/bullet.mp3', autoplay=False)
        self.death_message_shown = False

        self.spawn_points = [
            ursina.Vec3(0, 1, 0),
            ursina.Vec3(12, 1, 0),
            ursina.Vec3(0, 1, 12),
            ursina.Vec3(12, 1, 12),
            ursina.Vec3(-6, 1, -6),
            ursina.Vec3(6, 1, -6),
            # 1st Floor spawn points
            ursina.Vec3(0, 6, 14),
            ursina.Vec3(0, 6, -14),
            ursina.Vec3(16, 6, 0),
            ursina.Vec3(-16, 6, 0),
        ]

        # Persistent Death Screen UI elements (clean original background image)
        self.death_bg = ursina.Entity(
            parent=ursina.camera.ui,
            model="quad",
            texture="assets/background.jpg",
            scale=ursina.Vec2(2.0, 1.05),
            position=ursina.Vec3(0, 0, 0.1),
            color=ursina.color.white,
            enabled=False
        )
        if self.death_bg.texture:
            self.death_bg.texture.filtering = 'bilinear'

        self.death_title = ursina.Text(
            text="YOU DIED",
            origin=ursina.Vec2(0, 0),
            y=0.2,
            z=-0.05,
            scale=3.5,
            color=ursina.color.red,
            enabled=False
        )

        self.death_subtitle = ursina.Text(
            text="Press [R] or [SPACE] to Respawn  |  [ESC] to Exit",
            origin=ursina.Vec2(0, 0),
            y=0.08,
            z=-0.05,
            scale=1.3,
            color=ursina.color.white,
            enabled=False
        )

        self.respawn_button = ursina.Button(
            text="RESPAWN",
            color=ursina.color.azure,
            highlight_color=ursina.color.cyan,
            scale=ursina.Vec2(0.25, 0.08),
            position=ursina.Vec3(0, -0.05, -0.05),
            on_click=self.respawn,
            enabled=False
        )

        self.respawn_timer = 0
        self.timer_text = ursina.Text(
            text="Auto-respawn in 5s...",
            origin=ursina.Vec2(0, 0),
            y=-0.14,
            z=-0.05,
            scale=1.1,
            color=ursina.color.light_gray,
            enabled=False
        )

    def death(self):
        if self.death_message_shown:
            return
        self.death_message_shown = True

        self.gravity = 0
        self.gun.enabled = False
        self.healthbar.enabled = False
        self.healthbar_bg.enabled = False
        if hasattr(self, 'health_text') and self.health_text:
            self.health_text.enabled = False

        self.rotation = ursina.Vec3(0, 0, 0)
        self.camera_pivot.world_rotation_x = -45
        self.world_position = ursina.Vec3(0, 7, -35)
        self.cursor.color = ursina.color.rgba(0, 0, 0, a=0)

        ursina.mouse.locked = False
        ursina.mouse.visible = True

        if self.network:
            self.network.send_player(self)

        if hasattr(self, 'death_bg') and self.death_bg:
            aspect = getattr(ursina.camera, 'aspect_ratio', 16/9)
            self.death_bg.scale = ursina.Vec2(max(aspect, 1.8) * 1.02, 1.02)
            self.death_bg.color = ursina.color.white
            self.death_bg.enabled = True

        self.death_title.enabled = True
        self.death_subtitle.enabled = True
        self.respawn_button.enabled = True
        self.respawn_timer = 5.0
        self.timer_text.text = f"Auto-respawn in {int(self.respawn_timer)}s..."
        self.timer_text.enabled = True

    def respawn(self):
        if not self.death_message_shown and self.health > 0:
            return

        import random

        # Hide death UI elements safely without destroying them
        if hasattr(self, 'death_bg') and self.death_bg:
            self.death_bg.enabled = False
        if self.death_title:
            self.death_title.enabled = False
        if self.death_subtitle:
            self.death_subtitle.enabled = False
        if self.respawn_button:
            self.respawn_button.enabled = False
        if self.timer_text:
            self.timer_text.enabled = False

        self.health = self.max_health
        self.gravity = 1
        self.air_time = 0
        self.death_message_shown = False

        spawn_pos = random.choice(self.spawn_points)
        self.world_position = spawn_pos
        self.rotation = ursina.Vec3(0, 0, 0)
        self.camera_pivot.world_rotation_x = 0
        self.camera_pivot.rotation = ursina.Vec3(0, 0, 0)

        self.gun.enabled = True
        self.healthbar.enabled = True
        self.healthbar_bg.enabled = True
        self.healthbar.scale_x = self.healthbar_size.x
        if hasattr(self, 'health_text') and self.health_text:
            self.health_text.enabled = True
            self.health_text.text = f"{int(self.health)} / {self.max_health} HP"

        self.cursor.color = ursina.color.rgba(255, 0, 0, 122)
        ursina.mouse.locked = True
        ursina.mouse.visible = False

        if self.network:
            if hasattr(self.network, 'send_respawn'):
                self.network.send_respawn(self.world_position, self.health)
            self.network.send_player(self)

    def update(self):
        if self.health > 0:
            if self.world_y < -20:
                self.health = 0
                self.death()
                return

            if hasattr(self, 'healthbar') and self.healthbar and self.healthbar.enabled:
                self.healthbar.scale_x = max(0.0, (self.health / float(self.max_health)) * self.healthbar_size.x)
            if hasattr(self, 'health_text') and self.health_text and self.health_text.enabled:
                self.health_text.text = f"{int(max(0, self.health))} / {self.max_health} HP"

            super().update()
        else:
            if not self.death_message_shown:
                self.death()
            else:
                if hasattr(self, 'respawn_timer') and self.respawn_timer > 0:
                    self.respawn_timer -= ursina.time.dt
                    if hasattr(self, 'timer_text') and self.timer_text:
                        seconds_left = max(1, int(self.respawn_timer + 0.99))
                        self.timer_text.text = f"Auto-respawn in {seconds_left}s..."
                    if self.respawn_timer <= 0:
                        self.respawn()

    def input(self, key):
        if self.health <= 0:
            if key in ('r', 'space', 'enter'):
                self.respawn()
            return

        if key == 'space':
            self.jump()

