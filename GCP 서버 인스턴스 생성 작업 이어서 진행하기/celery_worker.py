from celery import Celery

celery = Celery(
    'celery_worker',
    broker='redis://redis:6379/0',
    backend='redis://redis:6379/0'
)

@celery.task
def add(x, y):
    return x + y


