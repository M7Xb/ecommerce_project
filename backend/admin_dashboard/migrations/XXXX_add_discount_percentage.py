from django.db import migrations, models

class Migration(migrations.Migration):

    dependencies = [
        ('admin_dashboard', '0004_deal'),
    ]

    operations = [
        migrations.AddField(
            model_name='deal',
            name='discount_percentage',
            field=models.IntegerField(default=0),
            preserve_default=False,
        ),
    ]