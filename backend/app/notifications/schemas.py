from pydantic import BaseModel

class NotificationCreate(BaseModel):
    message: str
    user_id: int
